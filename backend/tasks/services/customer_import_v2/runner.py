"""
Importun bazaya toxunan hissəsi: yükləmə, yoxlama (önbaxış), yaratma, davam etdirmə, ləğv, geri qaytarma.

Təhlükəsizlik qaydaları:
  * Mövcud müştərilər heç vaxt dəyişdirilmir və silinmir.
  * Yaratma 200-lük hissələrlə gedir; hər hissə (müştərilər + tarixçə qeydi) BİR tranzaksiyadır.
    Proses kəsilsə yarımçıq hissə tam ləğv olunur — "Davam et" qalanları yaradır.
  * Yaratmadan dərhal əvvəl dublikat yoxlaması bazaya qarşı yenidən aparılır.
  * Eyni anda yalnız bir import/geri qaytarma işləyə bilər (verilənlər bazası kilidi).
  * Geri qaytarma yalnız ən son importa və yalnız onun yaratdıqlarına aiddir.
"""
import hashlib
import logging
import threading
from datetime import timedelta

from django.conf import settings
from django.core.files.base import ContentFile
from django.db import DEFAULT_DB_ALIAS, close_old_connections, connection, transaction
from django.db.models import Count
from django.db.models.deletion import Collector, ProtectedError, RestrictedError
from django.utils import timezone

from tasks.models import Customer, CustomerImportBatch, CustomerImportRow, Equipment, OpticBox, Task
from users.models import Region

from . import analysis
from .analysis import CREATED, DUPLICATE_IN_FILE, EXISTING, NEW, PROBLEM, ExistingIndex, RefCatalog
from .normalize import best_match, clean_text
from .parsers import ImportFileError, MAX_FILE_SIZE, detect_source, parse_file

logger = logging.getLogger(__name__)

Batch = CustomerImportBatch
Status = CustomerImportBatch.Status

CHUNK_SIZE = 200
STALE_AFTER = timedelta(minutes=3)
LOCK_ID = 774_210_901  # pg advisory lock açarı (yalnız bu import üçün)

REF_MODELS = {"region": Region, "equipment": Equipment, "optic_box": OpticBox}


class ImportActionError(Exception):
    """İstifadəçiyə göstəriləcək qadağa/xəta mesajı."""


# ---------------------------------------------------------------------------
# Köməkçilər
# ---------------------------------------------------------------------------

def _lock():
    """Tranzaksiya daxilində qlobal kilid — eyni anda iki yazma əməliyyatı olmasın."""
    if connection.vendor == "postgresql":
        with connection.cursor() as cur:
            cur.execute("SELECT pg_advisory_xact_lock(%s)", [LOCK_ID])


def _run_in_background(fn, *args):
    if getattr(settings, "CUSTOMER_IMPORT_SYNC", False):
        fn(*args)
        return

    def target():
        close_old_connections()
        try:
            fn(*args)
        finally:
            connection.close()

    threading.Thread(target=target, daemon=True).start()


def _touch(batch_id, **fields):
    fields["heartbeat_at"] = timezone.now()
    Batch.objects.filter(pk=batch_id).update(**fields)


def build_index():
    index = ExistingIndex()
    qs = Customer.objects.values_list("id", "register_number", "phone_number", "full_name")
    for cid, reg, phone, name in qs.iterator(chunk_size=5000):
        index.add_customer(cid, reg, phone, name)
    return index


def build_catalogs():
    return {
        kind: RefCatalog(kind, list(model.objects.values("id", "name", "is_active")))
        for kind, model in REF_MODELS.items()
    }


def customer_snapshots(ids):
    ids = [i for i in set(ids) if i]
    out = {}
    if not ids:
        return out
    for c in Customer.objects.filter(id__in=ids).select_related("region", "equipment", "optic_box"):
        coords = c.address_coordinates if isinstance(c.address_coordinates, dict) else {}
        out[c.id] = {
            "id": c.id,
            "full_name": c.full_name,
            "register_number": c.register_number,
            "phone_number": c.phone_number,
            "region": c.region.name if c.region_id else "",
            "equipment": c.equipment.name if c.equipment_id else "",
            "optic_box": c.optic_box.name if c.optic_box_id else "",
            "address": c.address,
            "lat": coords.get("lat"),
            "lng": coords.get("lng"),
            "is_active": c.is_active,
            "has_passport_image": bool(c.passport_image),
            "created_at": c.created_at.isoformat() if c.created_at else None,
        }
    return out


def _attach_snapshots(matches, snaps):
    for m in matches:
        m["customer"] = snaps.get(m["customer_id"])
    return matches


def refresh_stale(batch):
    """Proses kəsilibsə (deploy, restart) statusu düzəldir. Data dəyişmir."""
    if batch.status not in Batch.RUNNING_STATUSES:
        return batch
    last = batch.heartbeat_at or batch.confirmed_at or batch.created_at
    if last and timezone.now() - last < STALE_AFTER:
        return batch
    with transaction.atomic():
        b = Batch.objects.select_for_update().get(pk=batch.pk)
        if b.status not in Batch.RUNNING_STATUSES:
            return b
        last = b.heartbeat_at or b.confirmed_at or b.created_at
        if last and timezone.now() - last < STALE_AFTER:
            return b
        if b.status == Status.VALIDATING:
            b.status = Status.FAILED
            b.error_message = "Faylın yoxlanması yarımçıq kəsildi (server yenidən başladı). Faylı yenidən yükləyin — heç nə yaradılmayıb."
        elif b.status == Status.IMPORTING:
            b.status = Status.INTERRUPTED
            b.error_message = (
                "Yaratma prosesi yarımçıq kəsildi. Yaradılmış müştərilər qorunub, yarımçıq qalan hissə ləğv olunub. "
                "“Davam et” ilə qalanları yaradın və ya “Geri qaytar” ilə hamısını ləğv edin."
            )
        elif b.status == Status.ROLLING_BACK:
            b.status = b.rollback_summary.get("previous_status") or Status.COMPLETED
            b.error_message = "Geri qaytarma yarımçıq kəsildi və heç nə silinmədi. Yenidən cəhd edə bilərsiniz."
        b.phase = ""
        b.save(update_fields=["status", "error_message", "phase"])
        return b


def blocking_batch(exclude_id=None):
    """Yeni əməliyyata mane olan import (işləyən və ya yarımçıq qalmış)."""
    qs = Batch.objects.filter(
        status__in=[Status.VALIDATING, Status.IMPORTING, Status.ROLLING_BACK, Status.INTERRUPTED]
    )
    if exclude_id:
        qs = qs.exclude(pk=exclude_id)
    for b in qs:
        b = refresh_stale(b)
        if b.status in (Status.VALIDATING, Status.IMPORTING, Status.ROLLING_BACK, Status.INTERRUPTED):
            return b
    return None


def _delete_file(batch):
    if batch.file:
        try:
            batch.file.delete(save=False)
        except Exception:  # fayl artıq yoxdursa
            logger.warning("Import faylı silinmədi: %s", batch.file.name)
        Batch.objects.filter(pk=batch.pk).update(file=None)


# ---------------------------------------------------------------------------
# 1. Yükləmə və yoxlama (önbaxış) — heç bir müştəri yaradılmır
# ---------------------------------------------------------------------------

def upload(uploaded_file, user):
    name = uploaded_file.name or "fayl"
    if uploaded_file.size and uploaded_file.size > MAX_FILE_SIZE:
        raise ImportFileError("Fayl çox böyükdür (maksimum 10 MB). Faylı hissələrə bölüb yükləyin.")
    content = uploaded_file.read()
    if not content:
        raise ImportFileError("Fayl boşdur.")
    if len(content) > MAX_FILE_SIZE:
        raise ImportFileError("Fayl çox böyükdür (maksimum 10 MB). Faylı hissələrə bölüb yükləyin.")
    source = detect_source(name, content[:8])
    sha = hashlib.sha256(content).hexdigest()

    with transaction.atomic():
        _lock()
        blocker = blocking_batch()
        if blocker:
            if blocker.status == Status.INTERRUPTED:
                raise ImportActionError(
                    "Əvvəlki import yarımçıq qalıb. Əvvəlcə onu “Davam et” ilə bitirin və ya “Geri qaytar” edin."
                )
            raise ImportActionError("Hazırda başqa bir import işləyir. Bitməsini gözləyin.")
        # Təsdiqlənməmiş köhnə önbaxışlar artıq köhnəlib — ləğv olunur
        stale_previews = list(Batch.objects.filter(status=Status.PREVIEW))
        for p in stale_previews:
            p.status = Status.CANCELLED
            p.phase = ""
            p.error_message = "Yeni fayl yükləndiyi üçün avtomatik ləğv olundu."
            p.save(update_fields=["status", "phase", "error_message"])

        notes = []
        same = (
            Batch.objects.filter(file_sha256=sha)
            .exclude(status__in=[Status.CANCELLED, Status.FAILED])
            .order_by("-created_at").first()
        )
        if same:
            notes.append({
                "code": "same_file",
                "message": f"Bu fayl əvvəl də yüklənib ({timezone.localtime(same.created_at):%d.%m.%Y %H:%M}). "
                           "Artıq yaradılmış müştərilər təkrar yaradılmayacaq.",
            })
        batch = Batch(
            source_type=source,
            original_filename=name[:255],
            file_sha256=sha,
            file_size=len(content),
            status=Status.VALIDATING,
            phase="Fayl oxunur",
            created_by=user,
            heartbeat_at=timezone.now(),
            summary={"notes": notes},
        )
        batch.file.save(name[-120:], ContentFile(content), save=False)
        batch.save()

    for p in stale_previews:
        _delete_file(p)
    _run_in_background(run_validation, str(batch.pk))
    return batch


def run_validation(batch_id):
    try:
        batch = Batch.objects.get(pk=batch_id)
        with batch.file.open("rb") as fh:
            content = fh.read()
        try:
            source, parsed = parse_file(batch.original_filename, content)
        except ImportFileError as exc:
            _touch(batch_id, status=Status.FAILED, phase="", error_message=str(exc), finished_at=timezone.now())
            return

        total = len(parsed.rows)
        _touch(batch_id, phase="Məlumatlar yoxlanılır", total_rows=total, progress_total=total, progress_done=0)

        index = build_index()
        catalogs = build_catalogs()
        outcomes = analysis.analyze_rows(
            parsed.rows, index, catalogs,
            progress=lambda n: _touch(batch_id, progress_done=n),
        )

        _touch(batch_id, phase="Nəticələr hazırlanır", progress_done=total)
        snaps = customer_snapshots(m["customer_id"] for o in outcomes for m in o["matches"])

        counts = {NEW: 0, EXISTING: 0, DUPLICATE_IN_FILE: 0, PROBLEM: 0}
        warning_rows = 0
        planned = {"region": {}, "equipment": {}, "optic_box": {}}
        row_objs = []
        for o in outcomes:
            counts[o["result"]] += 1
            if o["warnings"]:
                warning_rows += 1
            if o["result"] == NEW:
                for kind in planned:
                    d = o["data"].get(kind)
                    if d and d.get("action") == "create":
                        planned[kind][d["name"]] = planned[kind].get(d["name"], 0) + 1
            row_objs.append(CustomerImportRow(
                batch_id=batch_id,
                row_number=o["row_number"],
                raw=o["raw"],
                data=o["data"],
                keys=[[k, f] for k, f in o["keyed"]],
                result=o["result"],
                reasons=o["reasons"],
                warnings=o["warnings"],
                matches=_attach_snapshots(o["matches"], snaps),
                duplicate_of_row=o["duplicate_of_row"],
            ))

        with transaction.atomic():
            b = Batch.objects.select_for_update().get(pk=batch_id)
            if b.status != Status.VALIDATING:
                return  # ləğv olunub
            CustomerImportRow.objects.filter(batch_id=batch_id).delete()
            CustomerImportRow.objects.bulk_create(row_objs, batch_size=1000)
            summary = dict(b.summary or {})
            summary["notes"] = (summary.get("notes") or []) + parsed.notes
            summary["planned_refs"] = {
                kind: [{"name": n, "rows": c} for n, c in sorted(v.items())] for kind, v in planned.items()
            }
            b.summary = summary
            b.source_type = source
            b.total_rows = total
            b.new_count = counts[NEW]
            b.existing_count = counts[EXISTING]
            b.duplicate_in_file_count = counts[DUPLICATE_IN_FILE]
            b.problem_count = counts[PROBLEM]
            b.warning_count = warning_rows
            b.status = Status.PREVIEW
            b.phase = ""
            b.progress_done = total
            b.heartbeat_at = timezone.now()
            b.save()
    except Exception as exc:  # gözlənilməz xəta — heç nə yaradılmayıb
        logger.exception("Customer import validation failed")
        _touch(batch_id, status=Status.FAILED, phase="",
               error_message=f"Fayl yoxlanarkən gözlənilməz xəta baş verdi: {exc}. Heç bir müştəri yaradılmayıb.",
               finished_at=timezone.now())


def cancel(batch):
    with transaction.atomic():
        b = Batch.objects.select_for_update().get(pk=batch.pk)
        if b.status not in (Status.PREVIEW, Status.FAILED):
            raise ImportActionError("Yalnız təsdiq gözləyən importu ləğv etmək olar.")
        b.status = Status.CANCELLED
        b.phase = ""
        b.finished_at = timezone.now()
        b.save(update_fields=["status", "phase", "finished_at"])
    _delete_file(b)
    return b


# ---------------------------------------------------------------------------
# 2. Yaratma (təsdiqdən sonra) və davam etdirmə
# ---------------------------------------------------------------------------

def confirm(batch, user):
    with transaction.atomic():
        _lock()
        b = Batch.objects.select_for_update().get(pk=batch.pk)
        if b.status != Status.PREVIEW:
            raise ImportActionError("Bu import artıq təsdiq gözləmir.")
        blocker = blocking_batch(exclude_id=b.pk)
        if blocker:
            raise ImportActionError("Başqa bir import işləyir və ya yarımçıq qalıb. Əvvəlcə onu bitirin.")
        if b.new_count == 0:
            raise ImportActionError("Yaradılacaq yeni müştəri yoxdur.")
        b.status = Status.IMPORTING
        b.phase = "Müştərilər yaradılır"
        b.confirmed_by = user
        b.confirmed_at = timezone.now()
        b.progress_total = b.new_count
        b.progress_done = 0
        b.error_message = ""
        b.heartbeat_at = timezone.now()
        b.created_refs = b.created_refs or {"region": [], "equipment": [], "optic_box": []}
        b.save()
    _run_in_background(run_import, str(b.pk))
    return b


def resume(batch, user):
    with transaction.atomic():
        _lock()
        b = Batch.objects.select_for_update().get(pk=batch.pk)
        if b.status != Status.INTERRUPTED:
            raise ImportActionError("Yalnız yarımçıq qalmış importu davam etdirmək olar.")
        b.status = Status.IMPORTING
        b.phase = "Müştərilər yaradılır (davam)"
        b.error_message = ""
        b.heartbeat_at = timezone.now()
        b.save(update_fields=["status", "phase", "error_message", "heartbeat_at"])
    _run_in_background(run_import, str(b.pk))
    return b


class _RowProblem(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


def _ensure_ref(kind, decision, catalogs, created_refs):
    """Yaratma anında region/avadanlığı bazaya qarşı yenidən həll edir; lazımdırsa yaradır."""
    if not decision:
        return None
    label = analysis.REF_LABELS[kind]
    catalog = catalogs[kind]
    obj, _score, ambiguous = best_match(decision["input"], catalog.candidates)
    if ambiguous:
        raise _RowProblem(f"{kind}_ambiguous", f"{label} «{decision['input']}» bir neçə mövcud ada oxşayır. Dəqiq adı yazın.")
    if obj is not None and obj.get("id"):
        if not obj.get("is_active", True):
            raise _RowProblem(f"{kind}_inactive", f"{label} «{obj['name']}» sistemdə deaktiv edilib.")
        return obj["id"]
    model = REF_MODELS[kind]
    name = clean_text(decision["input"])
    existing = model.objects.filter(name=name).first()
    if existing:
        if not existing.is_active:
            raise _RowProblem(f"{kind}_inactive", f"{label} «{existing.name}» sistemdə deaktiv edilib.")
        new_obj = existing
    else:
        kwargs = {"name": name, "is_active": True}
        if kind != "region":
            kwargs["description"] = ""
        new_obj = model.objects.create(**kwargs)
        created_refs.setdefault(kind, []).append(new_obj.id)
    item = {"id": new_obj.id, "name": new_obj.name, "is_active": True, "planned": False}
    catalog.candidates.append((analysis.normalize_name(new_obj.name), item))
    return new_obj.id


def run_import(batch_id):
    try:
        index = build_index()
        catalogs = build_catalogs()
        pending_ids = list(
            CustomerImportRow.objects.filter(batch_id=batch_id, result=NEW, created_customer__isnull=True)
            .order_by("row_number").values_list("id", flat=True)
        )
        for start in range(0, len(pending_ids), CHUNK_SIZE):
            chunk_ids = pending_ids[start:start + CHUNK_SIZE]
            with transaction.atomic():
                _lock()
                b = Batch.objects.select_for_update().get(pk=batch_id)
                if b.status != Status.IMPORTING:
                    return
                created_refs = dict(b.created_refs or {})
                rows = list(CustomerImportRow.objects.select_for_update()
                            .filter(id__in=chunk_ids, result=NEW, created_customer__isnull=True)
                            .order_by("row_number"))
                to_create, row_for, changed = [], [], []
                late_existing = []
                for row in rows:
                    keyed = [(k, f) for k, f in row.keys]
                    hits = index.lookup(keyed)
                    if hits:
                        row.result = EXISTING
                        row.matches = [{"customer_id": cid, "matched_on": on} for cid, on in hits.items()]
                        row.reasons = [{"code": "exists_after_preview",
                                        "message": "Önbaxışdan sonra bu nömrə ilə müştəri sistemə əlavə olunub — yaradılmadı."}]
                        late_existing.append(row)
                        changed.append(row)
                        continue
                    data = row.data
                    try:
                        sid = transaction.savepoint()
                        try:
                            region_id = _ensure_ref("region", data.get("region"), catalogs, created_refs)
                            equipment_id = _ensure_ref("equipment", data.get("equipment"), catalogs, created_refs)
                            optic_id = _ensure_ref("optic_box", data.get("optic_box"), catalogs, created_refs)
                            transaction.savepoint_commit(sid)
                        except Exception:
                            transaction.savepoint_rollback(sid)
                            raise
                    except _RowProblem as p:
                        row.result = PROBLEM
                        row.reasons = (row.reasons or []) + [{"code": p.code, "message": p.message}]
                        changed.append(row)
                        continue
                    coords = {}
                    if data.get("lat") is not None and data.get("lng") is not None:
                        coords = {"lat": data["lat"], "lng": data["lng"]}
                    to_create.append(Customer(
                        full_name=data["full_name"],
                        register_number=data.get("register_number") or "",
                        phone_number=data.get("phone_number") or "",
                        region_id=region_id,
                        equipment_id=equipment_id,
                        optic_box_id=optic_id,
                        address=data.get("address") or "",
                        address_coordinates=coords,
                        bulk_created=True,
                        is_active=True,
                    ))
                    row_for.append(row)

                if to_create:
                    created = Customer.objects.bulk_create(to_create)
                    for row, cust in zip(row_for, created):
                        if not cust.pk:
                            raise RuntimeError("Yaradılan müştərinin id-si alınmadı")
                        row.created_customer = cust
                        row.result = CREATED
                        row.data = dict(row.data, created_id=cust.pk)
                        index.add_keys(cust.pk, [(k, f) for k, f in row.keys])
                        changed.append(row)

                if late_existing:
                    snaps = customer_snapshots(m["customer_id"] for r in late_existing for m in r.matches)
                    for r in late_existing:
                        _attach_snapshots(r.matches, snaps)
                if changed:
                    CustomerImportRow.objects.bulk_update(
                        changed, ["result", "matches", "reasons", "created_customer", "data"], batch_size=500
                    )

                n_created = len(to_create)
                n_existing = len(late_existing)
                n_problem = sum(1 for r in changed if r.result == PROBLEM)
                b.created_refs = created_refs
                b.created_count += n_created
                b.new_count -= (n_existing + n_problem)
                b.existing_count += n_existing
                b.problem_count += n_problem
                b.progress_done = min(b.progress_total, b.progress_done + len(rows))
                b.heartbeat_at = timezone.now()
                b.save()

        with transaction.atomic():
            b = Batch.objects.select_for_update().get(pk=batch_id)
            if b.status != Status.IMPORTING:
                return
            b.status = Status.COMPLETED
            b.phase = ""
            b.progress_done = b.progress_total
            b.finished_at = timezone.now()
            b.heartbeat_at = timezone.now()
            b.save()
        # Yer tutmasın: yalnız ən son importun faylı qalır
        for old in Batch.objects.exclude(pk=batch_id).exclude(file="").exclude(file__isnull=True):
            if old.status not in (Status.VALIDATING, Status.PREVIEW, Status.IMPORTING, Status.INTERRUPTED):
                _delete_file(old)
    except Exception as exc:
        logger.exception("Customer import failed")
        Batch.objects.filter(pk=batch_id, status=Status.IMPORTING).update(
            status=Status.INTERRUPTED,
            phase="",
            heartbeat_at=timezone.now(),
            error_message=(
                f"Yaratma zamanı xəta baş verdi: {exc}. Yaradılmış müştərilər qorunub, yarımçıq hissə ləğv olunub. "
                "“Davam et” və ya “Geri qaytar” seçin."
            ),
        )


# ---------------------------------------------------------------------------
# 3. Geri qaytarma — yalnız ən son import, yalnız onun yaratdıqları
# ---------------------------------------------------------------------------

def latest_confirmed_batch():
    return Batch.objects.filter(confirmed_at__isnull=False).order_by("-confirmed_at").first()


def can_rollback(batch):
    if batch.status not in (Status.COMPLETED, Status.INTERRUPTED):
        return False
    latest = latest_confirmed_batch()
    return bool(latest and latest.pk == batch.pk)


def _created_customer_ids(batch):
    return list(
        CustomerImportRow.objects.filter(batch=batch, created_customer__isnull=False)
        .values_list("created_customer_id", flat=True)
    )


def rollback_check(batch):
    """Nə silinəcək və nəyə görə bloklanır — heç nə dəyişmir."""
    ids = _created_customer_ids(batch)
    customers = Customer.objects.filter(id__in=ids)
    result = {
        "allowed": can_rollback(batch),
        "customers_to_delete": customers.count(),
        "with_passport_image": customers.exclude(passport_image="").exclude(passport_image__isnull=True).count(),
        "blocked": [],
        "blocked_other": [],
        "refs": {},
    }
    if not result["allowed"]:
        result["reason"] = "Yalnız ən son importu geri qaytarmaq olar."

    task_counts = (
        Task.objects.filter(customer_id__in=ids).values("customer_id").annotate(n=Count("id"))
    )
    task_map = {r["customer_id"]: r["n"] for r in task_counts}
    if task_map:
        for c in customers.filter(id__in=task_map.keys()).only("id", "full_name", "register_number")[:200]:
            result["blocked"].append({
                "id": c.id, "full_name": c.full_name, "register_number": c.register_number,
                "reason": f"{task_map[c.id]} tapşırığı var",
            })
        result["blocked_total"] = len(task_map)

    # Digər (gələcəkdə yaranacaq) əlaqələr: silinmə başqa məlumatı da silərsə və ya qadağandırsa — blokla
    if ids and not task_map:
        collector = Collector(using=DEFAULT_DB_ALIAS)
        try:
            collector.collect(list(customers))
            for model, objs in collector.data.items():
                if model is not Customer and objs:
                    result["blocked_other"].append(f"{model._meta.verbose_name_plural}: {len(objs)}")
            for qs in collector.fast_deletes:
                if qs.model is not Customer and qs.exists():
                    result["blocked_other"].append(f"{qs.model._meta.verbose_name_plural}: {qs.count()}")
        except (ProtectedError, RestrictedError) as exc:
            objs = getattr(exc, "protected_objects", None) or getattr(exc, "restricted_objects", None) or []
            result["blocked_other"].append(f"Əlaqəli məlumat var ({len(list(objs))})")

    refs = batch.created_refs or {}
    for kind, model in REF_MODELS.items():
        ref_ids = refs.get(kind) or []
        if not ref_ids:
            continue
        result["refs"][kind] = [{"id": o.id, "name": o.name} for o in model.objects.filter(id__in=ref_ids)]

    result["can_proceed"] = bool(
        result["allowed"] and not result["blocked"] and not result["blocked_other"]
        and batch.status in (Status.COMPLETED, Status.INTERRUPTED)
    )
    return result


def start_rollback(batch, user):
    with transaction.atomic():
        _lock()
        b = Batch.objects.select_for_update().get(pk=batch.pk)
        if not can_rollback(b):
            raise ImportActionError("Yalnız ən son importu və yalnız tamamlanmış/yarımçıq vəziyyətdə geri qaytarmaq olar.")
        blocker = blocking_batch(exclude_id=b.pk)
        if blocker and blocker.status != Status.INTERRUPTED:
            raise ImportActionError("Hazırda başqa bir əməliyyat işləyir. Bitməsini gözləyin.")
        check = rollback_check(b)
        if not check["can_proceed"]:
            raise ImportActionError(
                "Geri qaytarmaq olmur: bu importla yaradılmış bəzi müştərilərin artıq tapşırıqları (və ya başqa əlaqəli məlumatları) var. "
                "Onları silmək həmin məlumatları da itirərdi."
            )
        b.rollback_summary = {"previous_status": b.status}
        b.status = Status.ROLLING_BACK
        b.phase = "Geri qaytarılır"
        b.rolled_back_by = user
        b.heartbeat_at = timezone.now()
        b.error_message = ""
        b.save()
    _run_in_background(run_rollback, str(b.pk))
    return b


def _ref_in_use(kind, obj):
    """
    Import zamanı yaradılmış region/avadanlıq başqa yerdə istifadə olunurmu?
    İstifadə olunursa silinmir (silmək başqa məlumatı silər və ya boşaldardı).
    """
    if Customer.objects.filter(**{kind: obj}).exists():
        return True
    collector = Collector(using=DEFAULT_DB_ALIAS)
    try:
        collector.collect([obj])
    except (ProtectedError, RestrictedError):
        return True
    for model, objs in collector.data.items():
        if model is not type(obj) and objs:
            return True
    for qs in collector.fast_deletes:
        if qs.model is not type(obj) and qs.exists():
            return True
    # SET_NULL əlaqələri (Django boş sorğuları da əlavə edir — ona görə .exists() ilə yoxlanır)
    for objs_list in collector.field_updates.values():
        for objs in objs_list:
            if hasattr(objs, "exists"):
                if objs.exists():
                    return True
            elif objs:
                return True
    return False


def run_rollback(batch_id):
    try:
        files_to_delete = []
        with transaction.atomic():
            _lock()
            b = Batch.objects.select_for_update().get(pk=batch_id)
            if b.status != Status.ROLLING_BACK:
                return
            check = rollback_check(b)
            # can_rollback ROLLING_BACK statusunda False qaytarır — burada yalnız bloklara baxırıq
            if check["blocked"] or check["blocked_other"]:
                b.status = b.rollback_summary.get("previous_status") or Status.COMPLETED
                b.phase = ""
                b.error_message = "Geri qaytarma dayandırıldı: bəzi müştərilərin artıq tapşırıqları var. Heç nə silinmədi."
                b.save()
                return

            ids = _created_customer_ids(b)
            customers = Customer.objects.filter(id__in=ids)
            for c in customers.exclude(passport_image="").exclude(passport_image__isnull=True).only("id", "passport_image"):
                files_to_delete.append(c.passport_image.name)
            deleted_customers = customers.count()
            customers.delete()  # Task PROTECT-dir: tapşırıq yaranıbsa ProtectedError → bütün tranzaksiya ləğv

            kept, removed = {}, {}
            refs = b.created_refs or {}
            for kind, model in REF_MODELS.items():
                for obj in model.objects.filter(id__in=refs.get(kind) or []):
                    if _ref_in_use(kind, obj):
                        kept.setdefault(kind, []).append(obj.name)
                    else:
                        removed.setdefault(kind, []).append(obj.name)
                        obj.delete()

            storage = Customer._meta.get_field("passport_image").storage

            def _remove_files():
                for name in files_to_delete:
                    try:
                        storage.delete(name)
                    except Exception:
                        logger.warning("Passport şəkli silinmədi: %s", name)

            transaction.on_commit(_remove_files)

            b.rollback_summary = dict(
                b.rollback_summary or {},
                deleted_customers=deleted_customers,
                deleted_images=len(files_to_delete),
                removed_refs=removed,
                kept_refs=kept,
            )
            b.status = Status.ROLLED_BACK
            b.phase = ""
            b.rolled_back_at = timezone.now()
            b.heartbeat_at = timezone.now()
            b.save()
    except Exception as exc:
        logger.exception("Customer import rollback failed")
        b = Batch.objects.filter(pk=batch_id).first()
        if b and b.status == Status.ROLLING_BACK:
            prev = (b.rollback_summary or {}).get("previous_status") or Status.COMPLETED
            Batch.objects.filter(pk=batch_id).update(
                status=prev, phase="", heartbeat_at=timezone.now(),
                error_message=f"Geri qaytarma alınmadı və heç nə silinmədi: {exc}",
            )
