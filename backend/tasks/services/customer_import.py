import json
import os
import re
import threading
import time

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from tasks.models import Customer, CustomerImportJob, Equipment
from users.models import Region


ERROR_SAMPLE_LIMIT = 50
BATCH_SIZE = 1000


def _normalize_name(value):
    text = (value or "").strip().lower()
    table = str.maketrans(
        {
            "ə": "e",
            "ü": "u",
            "ö": "o",
            "ğ": "g",
            "ş": "s",
            "ç": "c",
            "ı": "i",
            "Ə": "e",
            "Ü": "u",
            "Ö": "o",
            "Ğ": "g",
            "Ş": "s",
            "Ç": "c",
            "İ": "i",
            "I": "i",
        }
    )
    text = text.translate(table)
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return re.sub(r"-{2,}", "-", text).strip("-")


def _find_contains_match(raw_name, normalized_pairs):
    key = _normalize_name(raw_name)
    if not key:
        return None
    for norm_name, obj in normalized_pairs:
        if key in norm_name or norm_name in key:
            return obj
    return None


def _register_value(raw_username, raw_phone):
    username = (raw_username or "").strip()
    phone = (raw_phone or "").strip()
    if username:
        return username
    return phone


def _json_path():
    return os.path.join(settings.BASE_DIR, "customers.json")


def _load_rows():
    with open(_json_path(), "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    raise ValueError("customers.json must be an array")


def start_customer_import_job(job_id):
    t = threading.Thread(target=run_customer_import_job, args=(str(job_id),), daemon=True)
    t.start()


def run_customer_import_job(job_id):
    started = time.monotonic()
    job = CustomerImportJob.objects.get(pk=job_id)
    job.status = CustomerImportJob.Status.RUNNING
    job.started_at = timezone.now()
    job.save(update_fields=["status", "started_at"])

    try:
        rows = _load_rows()
        job.total_rows = len(rows)
        job.save(update_fields=["total_rows"])

        existing_registers = set(
            Customer.objects.exclude(register_number="").values_list("register_number", flat=True)
        )

        regions = list(Region.objects.all())
        region_pairs = [(_normalize_name(r.name), r) for r in regions]
        equipments = list(Equipment.objects.all())
        equipment_pairs = [(_normalize_name(e.name), e) for e in equipments]

        to_create = []
        created = skipped = errors = processed = 0
        sample_errors = []

        for row in rows:
            processed += 1
            full_name = (row.get("fullname") or "").strip()
            register_number = _register_value(row.get("UserName"), row.get("phone"))
            phone = (row.get("phone") or "").strip()
            address = (row.get("address") or "").strip()
            raw_region = (row.get("region_name") or "").strip()
            raw_equipment = (row.get("equipment_name") or "").strip()

            if not register_number:
                errors += 1
                if len(sample_errors) < ERROR_SAMPLE_LIMIT:
                    sample_errors.append({"row": processed, "error": "empty register_number and phone"})
                continue

            if register_number in existing_registers:
                skipped += 1
                continue

            if not full_name:
                errors += 1
                if len(sample_errors) < ERROR_SAMPLE_LIMIT:
                    sample_errors.append({"row": processed, "register_number": register_number, "error": "empty fullname"})
                continue

            if not _normalize_name(raw_region):
                errors += 1
                if len(sample_errors) < ERROR_SAMPLE_LIMIT:
                    sample_errors.append({"row": processed, "register_number": register_number, "error": "empty region_name"})
                continue

            region = _find_contains_match(raw_region, region_pairs)
            if not region:
                region = Region.objects.create(name=raw_region, is_active=True)
                region_pairs.append((_normalize_name(region.name), region))

            equipment = None
            if _normalize_name(raw_equipment):
                equipment = _find_contains_match(raw_equipment, equipment_pairs)
                if not equipment:
                    equipment = Equipment.objects.create(
                        name=raw_equipment,
                        description="",
                        is_active=True,
                    )
                    equipment_pairs.append((_normalize_name(equipment.name), equipment))
                elif not equipment.is_active:
                    equipment.is_active = True
                    equipment.description = equipment.description or ""
                    equipment.save(update_fields=["is_active", "description"])

            to_create.append(
                Customer(
                    full_name=full_name,
                    register_number=register_number,
                    phone_number=phone,
                    region=region,
                    equipment=equipment,
                    address=address,
                    address_coordinates={},
                    is_active=True,
                    bulk_created=True,
                )
            )
            existing_registers.add(register_number)

            if len(to_create) >= BATCH_SIZE:
                with transaction.atomic():
                    Customer.objects.bulk_create(to_create, batch_size=BATCH_SIZE)
                created += len(to_create)
                to_create.clear()

            if processed % 500 == 0:
                CustomerImportJob.objects.filter(pk=job_id).update(
                    processed_rows=processed,
                    created_count=created,
                    skipped_count=skipped,
                    error_count=errors,
                    sample_errors=sample_errors,
                )

        if to_create:
            with transaction.atomic():
                Customer.objects.bulk_create(to_create, batch_size=BATCH_SIZE)
            created += len(to_create)

        duration_ms = int((time.monotonic() - started) * 1000)
        CustomerImportJob.objects.filter(pk=job_id).update(
            status=CustomerImportJob.Status.DONE,
            processed_rows=processed,
            created_count=created,
            skipped_count=skipped,
            error_count=errors,
            sample_errors=sample_errors,
            finished_at=timezone.now(),
            duration_ms=duration_ms,
        )
    except Exception as exc:
        duration_ms = int((time.monotonic() - started) * 1000)
        sample_errors = job.sample_errors or []
        sample_errors.append({"error": str(exc)})
        CustomerImportJob.objects.filter(pk=job_id).update(
            status=CustomerImportJob.Status.FAILED,
            finished_at=timezone.now(),
            duration_ms=duration_ms,
            sample_errors=sample_errors[:ERROR_SAMPLE_LIMIT],
        )

