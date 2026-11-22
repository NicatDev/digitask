"""
Müştəri importu — əlavə edge case testləri.
İşə salmaq:  python manage.py test tasks.test_customer_import_edge --settings=core.settings_test
"""
import io
import os
from datetime import timedelta
from unittest import mock

from django.core.files.base import ContentFile
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone

from tasks import test_customer_import as base
from tasks.models import Customer, CustomerImportBatch, CustomerImportRow, Equipment, OpticBox
from tasks.services.customer_import_v2 import parsers, runner
from users.models import Group, Region

URL = base.URL


@override_settings(CUSTOMER_IMPORT_SYNC=True)
class EdgeCaseTests(base.ImportFlowTests):
    # Əsas sinfin testləri burada təkrar işləməsin (yalnız setUp və köməkçilər lazımdır)
    test_full_flow = None
    test_rollback_blocked_by_task = None
    test_only_latest_can_rollback = None
    test_customer_added_after_preview_is_not_duplicated = None
    test_interrupted_then_resume_no_duplicates = None
    test_excel_template_roundtrip = None
    test_file_errors = None
    test_old_json_format_accepted = None
    test_permissions = None
    test_template_and_sample_download = None
    test_rows_endpoint_groups_and_export = None

    def batch(self, resp):
        return CustomerImportBatch.objects.get(pk=resp.data["id"])

    def only_row(self, b):
        return CustomerImportRow.objects.get(batch=b)

    @staticmethod
    def codes(row):
        return [x["code"] for x in row.reasons]

    def upload_xlsx(self, wb):
        buf = io.BytesIO()
        wb.save(buf)
        f = SimpleUploadedFile("x.xlsx", buf.getvalue())
        return self.client.post(URL + "upload/", {"file": f}, format="multipart")

    # --- region / avadanlıq / optik qutu ---
    def test_ambiguous_region_is_problem(self):
        Region.objects.create(name="SURAXANI")  # normallaşdırılmış adı "Suraxanı" ilə eynidir
        b = self.batch(self.upload_json([{"full_name": "A", "phone_number": "0551000001", "region": "suraxani"}]))
        row = self.only_row(b)
        self.assertEqual(row.result, "problem")
        self.assertIn("region_ambiguous", self.codes(row))
        self.assertEqual(Region.objects.count(), 3)  # yeni region yaradılmayıb

    def test_inactive_equipment_is_problem_and_untouched(self):
        Equipment.objects.create(name="Köhnə OLT", description="", is_active=False)
        b = self.batch(self.upload_json([{"full_name": "A", "phone_number": "0551000002", "region": "Suraxanı",
                                          "equipment": "Köhnə OLT"}]))
        self.assertIn("equipment_inactive", self.codes(self.only_row(b)))
        self.assertFalse(Equipment.objects.get(name="Köhnə OLT").is_active)  # mövcud obyekt dəyişmir

    def test_optic_box_match_create_and_rollback(self):
        box = OpticBox.objects.create(name="Qutu-1", description="")
        items = [
            {"full_name": "A", "phone_number": "0551000003", "region": "Suraxanı", "optic_box": "qutu 1"},
            {"full_name": "B", "phone_number": "0551000004", "region": "Suraxanı", "optic_box": "Yeni Qutu X"},
        ]
        b = self.batch(self.upload_json(items))
        self.client.post(f"{URL}{b.pk}/confirm/")
        self.assertEqual(Customer.objects.get(full_name="A").optic_box_id, box.id)
        self.assertTrue(OpticBox.objects.filter(name="Yeni Qutu X").exists())
        self.client.post(f"{URL}{b.pk}/rollback/")
        self.assertFalse(OpticBox.objects.filter(name="Yeni Qutu X").exists())
        self.assertTrue(OpticBox.objects.filter(pk=box.pk).exists())

    def test_created_region_kept_on_rollback_if_used_elsewhere(self):
        b = self.batch(self.upload_json([{"full_name": "A", "phone_number": "0551000005", "region": "Təzə Region"}]))
        self.client.post(f"{URL}{b.pk}/confirm/")
        region = Region.objects.get(name="Təzə Region")
        Group.objects.create(region=region, name="Qrup")  # sonradan başqa yerdə istifadə olunur
        self.client.post(f"{URL}{b.pk}/rollback/")
        b.refresh_from_db()
        self.assertEqual(b.status, "rolled_back", b.error_message)
        self.assertTrue(Region.objects.filter(pk=region.pk).exists())   # region qalır
        self.assertTrue(Group.objects.filter(name="Qrup").exists())     # qrup silinmir
        self.assertEqual(b.rollback_summary["kept_refs"], {"region": ["Təzə Region"]})
        self.assertFalse(Customer.objects.filter(full_name="A").exists())

    # --- nömrələr ---
    def test_register_with_two_numbers_is_problem(self):
        b = self.batch(self.upload_json([{"full_name": "A", "register_number": "0551000006, 0551000007",
                                          "region": "Suraxanı"}]))
        self.assertIn("register_number_multiple", self.codes(self.only_row(b)))

    def test_multiple_phones_stored_and_second_matches_existing(self):
        b = self.batch(self.upload_json([
            {"full_name": "Çox nömrə", "phone_number": "055 100 00 08; 050 100 00 09", "region": "Suraxanı"},
            {"full_name": "İkincisi mövcud", "phone_number": "0551000010, 0501112233", "region": "Suraxanı"},
        ]))
        rows = self.rows(b.pk)
        self.assertEqual(rows[1].data["phone_number"], "0551000008, 0501000009")
        self.assertEqual(rows[2].result, "existing")  # ikinci telefon mövcud müştərinin telefonudur
        self.assertEqual(rows[2].matches[0]["customer_id"], self.cust_a.id)

    def test_deactivated_existing_customer_counts_as_existing(self):
        Customer.objects.filter(pk=self.cust_a.pk).update(is_active=False)
        b = self.batch(self.upload_json([{"full_name": "Yenidən", "phone_number": "0554264644", "region": "Suraxanı"}]))
        row = self.only_row(b)
        self.assertEqual(row.result, "existing")
        self.assertFalse(row.matches[0]["customer"]["is_active"])

    def test_same_name_warning(self):
        b = self.batch(self.upload_json([{"full_name": "mövcud a", "phone_number": "0551000011", "region": "Suraxanı"}]))
        row = self.only_row(b)
        self.assertEqual(row.result, "new")
        self.assertIn("same_name_existing", [w["code"] for w in row.warnings])
        self.assertTrue(row.matches[0]["same_name"])

    # --- fayl ---
    def test_json_non_object_and_unknown_keys(self):
        b = self.batch(self.upload_json([
            "sadəcə mətn",
            {"full_name": "A", "phone_number": "0551000012", "region": "Suraxanı", "rəng": "qırmızı"},
        ]))
        rows = self.rows(b.pk)
        self.assertIn("invalid_object", self.codes(rows[1]))
        self.assertEqual(rows[2].result, "new")
        self.assertIn("unknown_columns", [n["code"] for n in b.summary["notes"]])

    def test_row_and_size_limits(self):
        items = [{"full_name": f"L{i}", "phone_number": f"05510001{i:02d}", "region": "Suraxanı"} for i in range(4)]
        with mock.patch.object(parsers, "MAX_ROWS", 3):
            b = self.batch(self.upload_json(items))
        self.assertEqual(b.status, "failed")
        self.assertIn("çox", b.error_message)
        with mock.patch.object(runner, "MAX_FILE_SIZE", 10):
            resp = self.upload_json(items)
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(Customer.objects.count(), 3)

    def test_excel_title_row_above_header_and_extra_columns(self):
        import openpyxl
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["Müştəri siyahısı — noyabr"])  # başlıqdan yuxarıda sərlövhə
        ws.append([])
        ws.append(["№", "Ad Soyad", "Telefon", "Region", "Qeyd"])
        ws.append([1, "Başlıqlı", "0551000013", "Suraxanı", "lazım deyil"])
        b = self.batch(self.upload_xlsx(wb))
        self.assertEqual(b.status, "preview", b.error_message)
        self.assertEqual(b.new_count, 1)
        self.assertEqual(self.only_row(b).row_number, 4)
        self.assertIn("unknown_columns", [n["code"] for n in b.summary["notes"]])

    def test_excel_duplicate_column_rejected(self):
        import openpyxl
        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["Ad Soyad", "Telefon", "Telefon", "Region"])
        ws.append(["A", "0551000014", "0551000015", "Suraxanı"])
        b = self.batch(self.upload_xlsx(wb))
        self.assertEqual(b.status, "failed")
        self.assertIn("iki dəfə", b.error_message)

    # --- vəziyyət idarəsi ---
    def test_new_upload_cancels_pending_preview(self):
        b1 = self.batch(self.upload_json([{"full_name": "A", "phone_number": "0551000016", "region": "Suraxanı"}]))
        b2 = self.batch(self.upload_json([{"full_name": "B", "phone_number": "0551000017", "region": "Suraxanı"}]))
        b1.refresh_from_db()
        self.assertEqual(b1.status, "cancelled")
        self.assertEqual(b2.status, "preview")
        self.assertEqual(self.client.post(f"{URL}{b1.pk}/confirm/").status_code, 409)

    def test_upload_refused_while_another_import_running(self):
        CustomerImportBatch.objects.create(source_type="json", status="importing", heartbeat_at=timezone.now())
        resp = self.upload_json([{"full_name": "A", "phone_number": "0551000018", "region": "Suraxanı"}])
        self.assertEqual(resp.status_code, 409)

    def test_stale_statuses_recover(self):
        old = timezone.now() - timedelta(minutes=10)
        v = CustomerImportBatch.objects.create(source_type="json", status="validating", heartbeat_at=old)
        i = CustomerImportBatch.objects.create(source_type="json", status="importing", heartbeat_at=old)
        r = CustomerImportBatch.objects.create(source_type="json", status="rolling_back", heartbeat_at=old,
                                               rollback_summary={"previous_status": "completed"})
        fresh = CustomerImportBatch.objects.create(source_type="json", status="importing", heartbeat_at=timezone.now())
        self.client.get(URL)
        for b, expected in ((v, "failed"), (i, "interrupted"), (r, "completed"), (fresh, "importing")):
            b.refresh_from_db()
            self.assertEqual(b.status, expected)

    def test_process_killed_mid_import_then_resume(self):
        """Proses öldürülür (xəta tutulmur) → status 'importing' qalır → köhnəlir → 'interrupted' → davam."""
        items = [{"full_name": f"Kill{i}", "phone_number": f"05510002{i:02d}", "region": "Suraxanı"} for i in range(5)]
        bid = self.upload_json(items).data["id"]
        real = Customer.objects.bulk_create
        calls = {"n": 0}

        def killed(objs, *a, **kw):
            calls["n"] += 1
            if calls["n"] == 2:
                raise KeyboardInterrupt  # Exception deyil — kodumuz tutmur, proses ölmüş kimi
            return real(objs, *a, **kw)

        with mock.patch.object(runner, "CHUNK_SIZE", 2), \
                mock.patch.object(Customer.objects, "bulk_create", side_effect=killed):
            with self.assertRaises(KeyboardInterrupt):
                runner.confirm(CustomerImportBatch.objects.get(pk=bid), self.admin)
        b = CustomerImportBatch.objects.get(pk=bid)
        self.assertEqual(b.status, "importing")
        self.assertEqual(Customer.objects.filter(full_name__startswith="Kill").count(), 2)  # yarımçıq hissə yoxdur

        CustomerImportBatch.objects.filter(pk=bid).update(heartbeat_at=timezone.now() - timedelta(minutes=10))
        self.assertEqual(self.client.get(f"{URL}{bid}/").data["status"], "interrupted")
        with mock.patch.object(runner, "CHUNK_SIZE", 2):
            self.client.post(f"{URL}{bid}/resume/")
        b.refresh_from_db()
        self.assertEqual(b.status, "completed", b.error_message)
        self.assertEqual(Customer.objects.filter(full_name__startswith="Kill").count(), 5)
        self.assertEqual(b.created_count, 5)

    def test_rollback_deletes_passport_images(self):
        b = self.batch(self.upload_json([{"full_name": "Şəkilli", "phone_number": "0551000019", "region": "Suraxanı"}]))
        self.client.post(f"{URL}{b.pk}/confirm/")
        c = Customer.objects.get(full_name="Şəkilli")
        c.passport_image.save("p.png", ContentFile(b"x"), save=True)
        path = c.passport_image.path
        self.assertTrue(os.path.exists(path))
        check = self.client.get(f"{URL}{b.pk}/rollback-check/").data
        self.assertEqual(check["with_passport_image"], 1)
        # TestCase-də tranzaksiya commit olunmur — "commit-dən sonra" fayl silinməsini icra etdiririk
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(f"{URL}{b.pk}/rollback/")
        self.assertFalse(Customer.objects.filter(pk=c.pk).exists())
        self.assertFalse(os.path.exists(path))


@override_settings(CUSTOMER_IMPORT_SYNC=True)
class ShortNameTests(EdgeCaseTests):
    """Çox qısa / rəqəmli adla yeni region-avadanlıq yaradılmır."""

    test_ambiguous_region_is_problem = None
    test_inactive_equipment_is_problem_and_untouched = None
    test_optic_box_match_create_and_rollback = None
    test_created_region_kept_on_rollback_if_used_elsewhere = None
    test_register_with_two_numbers_is_problem = None
    test_multiple_phones_stored_and_second_matches_existing = None
    test_deactivated_existing_customer_counts_as_existing = None
    test_same_name_warning = None
    test_json_non_object_and_unknown_keys = None
    test_row_and_size_limits = None
    test_excel_title_row_above_header_and_extra_columns = None
    test_excel_duplicate_column_rejected = None
    test_new_upload_cancels_pending_preview = None
    test_upload_refused_while_another_import_running = None
    test_stale_statuses_recover = None
    test_process_killed_mid_import_then_resume = None
    test_rollback_deletes_passport_images = None

    def test_short_and_numeric_names_not_created(self):
        b = self.batch(self.upload_json([
            {"full_name": "A", "phone_number": "0551000020", "region": "s"},
            {"full_name": "B", "phone_number": "0551000021", "region": "123"},
            {"full_name": "C", "phone_number": "0551000022", "region": "Suraxanı", "optic_box": "y"},
            {"full_name": "D", "phone_number": "0551000023", "region": "Abşeron"},
        ]))
        rows = self.rows(b.pk)
        self.assertIn("region_too_short", self.codes(rows[1]))
        self.assertIn("region_too_short", self.codes(rows[2]))
        self.assertIn("optic_box_too_short", self.codes(rows[3]))
        self.assertEqual(rows[4].result, "new")
        self.assertEqual(b.summary["planned_refs"]["region"], [{"name": "Abşeron", "rows": 1}])

    def test_short_name_matching_existing_is_ok(self):
        Region.objects.create(name="AB")
        b = self.batch(self.upload_json([{"full_name": "A", "phone_number": "0551000024", "region": "ab"}]))
        self.assertEqual(self.only_row(b).result, "new")

    def test_coordinate_messages_show_values(self):
        b = self.batch(self.upload_json([
            {"full_name": "A", "phone_number": "0551000025", "region": "Suraxanı", "lat": 49.86, "lng": 40.4},
        ]))
        msg = self.only_row(b).reasons[0]["message"]
        self.assertIn("enlik 40.4, uzunluq 49.86", msg)
