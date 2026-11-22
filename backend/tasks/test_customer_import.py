"""
Yeni müştəri importu testləri.
İşə salmaq:  python manage.py test tasks.test_customer_import --settings=core.settings_test
"""
import io
import json
import shutil
import tempfile
from unittest import mock

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from tasks.models import Customer, CustomerImportBatch, CustomerImportRow, Equipment, OpticBox, Task
from tasks.services.customer_import_v2 import normalize as n
from tasks.services.customer_import_v2 import runner
from tasks.services.customer_import_v2.templates import build_excel_template
from users.models import Region, Role, User

URL = "/api/tasks/customer-imports/"


class NormalizeTests(TestCase):
    def test_number_key_formats(self):
        for v in ["+994 55 426-46-44", "0554264644", "554264644", "994554264644", 554264644, 554264644.0,
                  "(055) 426 46 44", "00994554264644"]:
            self.assertEqual(n.number_key(v), "N:554264644", v)

    def test_junk_and_short(self):
        for v in ["NULL", "null", "0", "-", "", None, "000000000", "N/A", "12", "  "]:
            self.assertIsNone(n.number_key(v), v)

    def test_corrupt_scientific(self):
        with self.assertRaises(n.NumberProblem):
            n.number_key("9.94502E+11")

    def test_letters_register(self):
        self.assertEqual(n.number_key("99999y"), "R:99999Y")

    def test_split_numbers(self):
        self.assertEqual(n.split_numbers("055 123 45 67, 050 765 43 21 / NULL"), ["055 123 45 67", "050 765 43 21"])

    def test_similarity_rules(self):
        sim = lambda a, b: n.name_similarity(n.normalize_name(a), n.normalize_name(b))
        self.assertEqual(sim("DGI95SW021", "DGI95SW022"), 0)                        # rəqəm fərqi
        self.assertLessEqual(sim("PBR Internet Equipment", "Office Internet Equipment"), 0.6)  # ortaq sözlər
        self.assertGreater(sim("Suraxany", "Suraxanı"), 0.6)                         # hərf səhvi
        self.assertEqual(sim("hovsan kend", "Hövsan-Kənd"), 1.0)
        self.assertGreater(sim("PBR Internet", "PBR Internet Equipment"), 0.6)        # içində olma
        self.assertLessEqual(sim("Olt", "Hövsan-MA5800-x17-OLT"), 0.6)

    def test_coordinates(self):
        self.assertEqual(n.parse_coordinate("40,4093"), 40.4093)
        self.assertIsNone(n.parse_coordinate("NULL"))
        with self.assertRaises(ValueError):
            n.parse_coordinate("abc")


@override_settings(CUSTOMER_IMPORT_SYNC=True)
class ImportFlowTests(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls._media = tempfile.mkdtemp()
        cls._media_override = override_settings(MEDIA_ROOT=cls._media)
        cls._media_override.enable()

    @classmethod
    def tearDownClass(cls):
        cls._media_override.disable()
        shutil.rmtree(cls._media, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        role = Role.objects.create(name="Admin", is_admin=True)
        self.admin = User.objects.create_user("admin", password="x", role=role)
        self.plain = User.objects.create_user("plain", password="x")
        self.client = APIClient()
        self.client.force_authenticate(self.admin)

        self.suraxani = Region.objects.create(name="Suraxanı")
        self.inactive = Region.objects.create(name="Köhnə Region", is_active=False)
        self.olt = Equipment.objects.create(name="Suraxanı_OLT61", description="")
        self.cust_a = Customer.objects.create(
            full_name="Mövcud A", register_number="554264644", phone_number="0501112233", region=self.suraxani)
        self.cust_null = Customer.objects.create(full_name="Köhnə NULL", register_number="NULL", region=self.suraxani)
        self.cust_letter = Customer.objects.create(full_name="Hərfli", register_number="99999Y", region=self.suraxani)
        self.before = list(Customer.objects.order_by("id").values())

    # --- köməkçilər ---
    def upload_json(self, items, name="m.json"):
        f = SimpleUploadedFile(name, json.dumps(items, ensure_ascii=False).encode("utf-8"), "application/json")
        return self.client.post(URL + "upload/", {"file": f}, format="multipart")

    def rows(self, batch_id):
        return {r.row_number: r for r in CustomerImportRow.objects.filter(batch_id=batch_id)}

    def assert_existing_untouched(self):
        ids = [c["id"] for c in self.before]
        now = list(Customer.objects.filter(id__in=ids).order_by("id").values())
        self.assertEqual(now, self.before)

    def base_items(self):
        return [
            {"full_name": "Yeni Bir", "register_number": "0551234567", "region": "suraxani"},              # 1 yeni
            {"full_name": "X", "phone_number": "+994 55 426 46 44", "region": "Suraxanı"},                 # 2 mövcud (telefon→qeydiyyat)
            {"full_name": "Y", "register_number": "501112233", "region": "Suraxanı"},                      # 3 mövcud (qeydiyyat→telefon)
            {"full_name": "Yeni İki", "register_number": "NULL", "phone_number": "0559998877",
             "region": "Yeni Rayon"},                                                                        # 4 yeni + region yaradılır
            {"full_name": "Nömrəsiz", "register_number": "NULL", "phone_number": "", "region": "Suraxanı"},  # 5 problem
            {"full_name": "Yeni Bir", "register_number": "0551234567", "region": "suraxani"},              # 6 faylda təkrar
            {"full_name": "Ziddiyyət 1", "phone_number": "0707777777", "region": "Suraxanı"},              # 7 problem
            {"full_name": "Ziddiyyət 2", "phone_number": "707777777", "region": "Suraxanı"},               # 8 problem
            {"full_name": "Korlanmış", "phone_number": "9.94502E+11", "region": "Suraxanı"},               # 9 problem
            {"full_name": "Deaktiv", "phone_number": "0771231231", "region": "Köhnə Region"},              # 10 problem
            {"full_name": "Yarım koord", "phone_number": "0771231232", "region": "Suraxanı", "lat": 40.4},  # 11 problem
            {"full_name": "Dəyişik", "phone_number": "0771231233", "region": "Suraxanı",
             "lat": 49.86, "lng": 40.40},                                                                    # 12 problem
            {"full_name": "Yeni Avadanlıq", "phone_number": "0771231234", "region": "Suraxanı",
             "equipment": "DGI95SW022"},                                                                     # 13 yeni + avadanlıq
            {"full_name": "", "phone_number": "0771231235", "region": "Suraxanı"},                         # 14 problem
            {"full_name": "Oxşar Region", "phone_number": "0771231236", "region": "Yeni Rayonn"},          # 15 yeni (eyni region)
            {"full_name": "Hərfli dublikat", "register_number": "99999y", "region": "Suraxanı"},           # 16 mövcud
            {"full_name": "Koordinatlı", "phone_number": "0771231237", "region": "Suraxanı",
             "address_coordinates": {"lat": "40,4211", "lng": "50.0012"}, "address": "Ünvan 1"},           # 17 yeni
        ]

    # --- testlər ---
    def test_full_flow(self):
        resp = self.upload_json(self.base_items())
        self.assertEqual(resp.status_code, 201, resp.content)
        batch = CustomerImportBatch.objects.get(pk=resp.data["id"])
        self.assertEqual(batch.status, "preview", batch.error_message)
        rows = self.rows(batch.pk)
        expect = {
            1: "new", 2: "existing", 3: "existing", 4: "new", 5: "problem", 6: "duplicate_in_file",
            7: "problem", 8: "problem", 9: "problem", 10: "problem", 11: "problem", 12: "problem",
            13: "new", 14: "problem", 15: "new", 16: "existing", 17: "new",
        }
        self.assertEqual({k: r.result for k, r in rows.items()}, expect)
        self.assertEqual(rows[6].duplicate_of_row, 1)
        self.assertEqual(rows[2].matches[0]["customer_id"], self.cust_a.id)
        self.assertEqual(rows[2].matches[0]["matched_on"][0]["existing_field"], "register_number")
        self.assertIn("coords_swapped", [r["code"] for r in rows[12].reasons])
        self.assertEqual(rows[15].data["region"]["action"], "create")
        # Önbaxışda heç nə yaradılmayıb
        self.assertEqual(Customer.objects.count(), 3)
        self.assertFalse(Region.objects.filter(name="Yeni Rayon").exists())

        resp = self.client.post(f"{URL}{batch.pk}/confirm/")
        self.assertEqual(resp.status_code, 200, resp.content)
        batch.refresh_from_db()
        self.assertEqual(batch.status, "completed", batch.error_message)
        self.assertEqual(batch.created_count, 5)
        self.assertEqual(Customer.objects.count(), 8)
        self.assertEqual(Region.objects.filter(name__startswith="Yeni Rayon").count(), 1)  # bir dəfə yaradılıb
        c1 = Customer.objects.get(full_name="Yeni Bir")
        self.assertEqual(c1.register_number, "0551234567")
        self.assertTrue(c1.bulk_created)
        c17 = Customer.objects.get(full_name="Koordinatlı")
        self.assertEqual(c17.address_coordinates, {"lat": 40.4211, "lng": 50.0012})
        self.assertTrue(Equipment.objects.filter(name="DGI95SW022").exists())
        self.assert_existing_untouched()

        # Eyni faylı yenidən yükləmək — dublikat yaratmır
        resp = self.upload_json(self.base_items())
        b2 = CustomerImportBatch.objects.get(pk=resp.data["id"])
        self.assertEqual(b2.new_count, 0)
        self.assertIn("same_file", [x["code"] for x in b2.summary["notes"]])
        resp = self.client.post(f"{URL}{b2.pk}/confirm/")
        self.assertEqual(resp.status_code, 409)
        self.assertEqual(Customer.objects.count(), 8)

        # Geri qaytarma — ən son təsdiqlənmiş import birincidir
        check = self.client.get(f"{URL}{batch.pk}/rollback-check/").data
        self.assertTrue(check["can_proceed"], check)
        self.assertEqual(check["customers_to_delete"], 5)
        resp = self.client.post(f"{URL}{batch.pk}/rollback/")
        self.assertEqual(resp.status_code, 200, resp.content)
        batch.refresh_from_db()
        self.assertEqual(batch.status, "rolled_back", batch.error_message)
        self.assertEqual(Customer.objects.count(), 3)
        self.assertFalse(Region.objects.filter(name="Yeni Rayon").exists())
        self.assertFalse(Equipment.objects.filter(name="DGI95SW022").exists())
        self.assert_existing_untouched()
        # Tarixçə qalır
        self.assertEqual(CustomerImportRow.objects.filter(batch=batch).count(), 17)
        # İkinci dəfə geri qaytarmaq olmur
        self.assertEqual(self.client.post(f"{URL}{batch.pk}/rollback/").status_code, 409)

    def test_rollback_blocked_by_task(self):
        resp = self.upload_json([{"full_name": "T", "phone_number": "0551111111", "region": "Suraxanı"}])
        bid = resp.data["id"]
        self.client.post(f"{URL}{bid}/confirm/")
        c = Customer.objects.get(full_name="T")
        Task.objects.create(customer=c, title="iş")
        check = self.client.get(f"{URL}{bid}/rollback-check/").data
        self.assertFalse(check["can_proceed"])
        self.assertEqual(check["blocked"][0]["id"], c.id)
        self.assertEqual(self.client.post(f"{URL}{bid}/rollback/").status_code, 409)
        self.assertTrue(Customer.objects.filter(pk=c.pk).exists())

    def test_only_latest_can_rollback(self):
        b1 = self.upload_json([{"full_name": "A1", "phone_number": "0552222221", "region": "Suraxanı"}]).data["id"]
        self.client.post(f"{URL}{b1}/confirm/")
        b2 = self.upload_json([{"full_name": "A2", "phone_number": "0552222222", "region": "Suraxanı"}]).data["id"]
        self.client.post(f"{URL}{b2}/confirm/")
        self.assertEqual(self.client.post(f"{URL}{b1}/rollback/").status_code, 409)
        self.assertEqual(self.client.post(f"{URL}{b2}/rollback/").status_code, 200)
        self.assertTrue(Customer.objects.filter(full_name="A1").exists())
        self.assertFalse(Customer.objects.filter(full_name="A2").exists())

    def test_customer_added_after_preview_is_not_duplicated(self):
        bid = self.upload_json([{"full_name": "Gec", "phone_number": "0553333333", "region": "Suraxanı"}]).data["id"]
        Customer.objects.create(full_name="Əl ilə", phone_number="553333333", region=self.suraxani)
        self.client.post(f"{URL}{bid}/confirm/")
        b = CustomerImportBatch.objects.get(pk=bid)
        self.assertEqual(b.created_count, 0)
        self.assertEqual(b.existing_count, 1)
        self.assertEqual(Customer.objects.filter(phone_number__endswith="553333333").count(), 1)

    def test_interrupted_then_resume_no_duplicates(self):
        items = [{"full_name": f"R{i}", "phone_number": f"05544400{i:02d}", "region": "Suraxanı"} for i in range(5)]
        bid = self.upload_json(items).data["id"]
        real = Customer.objects.bulk_create
        calls = {"n": 0}

        def flaky(objs, *a, **kw):
            calls["n"] += 1
            if calls["n"] == 2:
                raise RuntimeError("server düşdü")
            return real(objs, *a, **kw)

        with mock.patch.object(runner, "CHUNK_SIZE", 2), \
                mock.patch.object(Customer.objects, "bulk_create", side_effect=flaky):
            self.client.post(f"{URL}{bid}/confirm/")
        b = CustomerImportBatch.objects.get(pk=bid)
        self.assertEqual(b.status, "interrupted")
        self.assertEqual(Customer.objects.filter(full_name__startswith="R").count(), 2)  # yarımçıq hissə ləğv

        # Yarımçıq import varkən yeni fayl qəbul olunmur
        self.assertEqual(self.upload_json(items).status_code, 409)

        with mock.patch.object(runner, "CHUNK_SIZE", 2):
            self.client.post(f"{URL}{bid}/resume/")
        b.refresh_from_db()
        self.assertEqual(b.status, "completed", b.error_message)
        self.assertEqual(b.created_count, 5)
        self.assertEqual(Customer.objects.filter(full_name__startswith="R").count(), 5)

    def test_excel_template_roundtrip(self):
        import openpyxl
        wb = openpyxl.load_workbook(io.BytesIO(build_excel_template()))
        ws = wb["Müştərilər"]
        ws.append(["Excel Müştəri", 554777777, "055 477 77 78", "Suraxanı", "Suraxanı_OLT61", None, "Ünvan", 40.41, 50.0])
        ws.append([None] * 9)
        ws.append(["Excel İki", None, None, "Suraxanı"])  # nömrəsiz → problem
        buf = io.BytesIO()
        wb.save(buf)
        f = SimpleUploadedFile("m.xlsx", buf.getvalue())
        resp = self.client.post(URL + "upload/", {"file": f}, format="multipart")
        self.assertEqual(resp.status_code, 201, resp.content)
        b = CustomerImportBatch.objects.get(pk=resp.data["id"])
        self.assertEqual(b.status, "preview", b.error_message)
        self.assertEqual((b.new_count, b.problem_count, b.total_rows), (1, 1, 2))
        row = CustomerImportRow.objects.get(batch=b, result="new")
        self.assertEqual(row.data["register_number"], "0554777777")
        self.assertEqual(row.data["equipment"]["id"], self.olt.id)

    def test_file_errors(self):
        f = SimpleUploadedFile("m.csv", b"a,b")
        self.assertEqual(self.client.post(URL + "upload/", {"file": f}, format="multipart").status_code, 400)
        f = SimpleUploadedFile("m.xlsx", b"not a zip")
        self.assertEqual(self.client.post(URL + "upload/", {"file": f}, format="multipart").status_code, 400)
        resp = self.client.post(URL + "upload/", {"file": SimpleUploadedFile("m.json", b"{bad")}, format="multipart")
        b = CustomerImportBatch.objects.get(pk=resp.data["id"])
        self.assertEqual(b.status, "failed")
        self.assertIn("JSON", b.error_message)
        resp = self.upload_json([{"foo": 1, "bar": 2}])
        b = CustomerImportBatch.objects.get(pk=resp.data["id"])
        self.assertEqual(b.status, "failed")
        self.assertEqual(Customer.objects.count(), 3)

    def test_old_json_format_accepted(self):
        items = [{"UserName": "NULL", "fullname": "Köhnə Format", "region_name": "Suraxanı",
                  "equipment_name": "NULL", "phone": "515838763", "address": "Hövsan"}]
        b = CustomerImportBatch.objects.get(pk=self.upload_json(items).data["id"])
        self.assertEqual(b.new_count, 1, b.error_message)
        row = CustomerImportRow.objects.get(batch=b)
        self.assertIsNone(row.data["equipment"])          # "NULL" avadanlıq yaradılmır
        self.assertEqual(row.data["phone_number"], "0515838763")

    def test_permissions(self):
        c = APIClient()
        c.force_authenticate(self.plain)
        self.assertEqual(c.get(URL).status_code, 403)
        self.assertEqual(c.get(URL + "template/").status_code, 403)

    def test_template_and_sample_download(self):
        r = self.client.get(URL + "template/")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.content.startswith(b"PK"))
        r = self.client.get(URL + "sample-json/")
        self.assertEqual(r.status_code, 200)
        self.assertIsInstance(json.loads(r.content), list)

    def test_rows_endpoint_groups_and_export(self):
        bid = self.upload_json(self.base_items()).data["id"]
        r = self.client.get(f"{URL}{bid}/rows/", {"group": "existing"})
        self.assertEqual(r.data["count"], 4)  # 3 mövcud + 1 faylda təkrar
        r = self.client.get(f"{URL}{bid}/rows/", {"group": "problem", "search": "Korlanmış"})
        self.assertEqual(r.data["count"], 1)
        r = self.client.get(f"{URL}{bid}/rows/export/", {"group": "problem"})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.content.startswith(b"PK"))
