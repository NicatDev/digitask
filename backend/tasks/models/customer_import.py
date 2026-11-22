import uuid

from django.conf import settings
from django.db import models


class CustomerImportBatch(models.Model):
    """Bir Excel/JSON müştəri importu — önbaxış, yaratma, geri qaytarma və tarixçə."""

    class Source(models.TextChoices):
        EXCEL = "excel", "Excel"
        JSON = "json", "JSON"

    class Status(models.TextChoices):
        VALIDATING = "validating", "Yoxlanılır"
        PREVIEW = "preview", "Təsdiq gözləyir"
        IMPORTING = "importing", "Yaradılır"
        COMPLETED = "completed", "Tamamlandı"
        INTERRUPTED = "interrupted", "Yarımçıq qaldı"
        FAILED = "failed", "Alınmadı"
        CANCELLED = "cancelled", "Ləğv edildi"
        ROLLING_BACK = "rolling_back", "Geri qaytarılır"
        ROLLED_BACK = "rolled_back", "Geri qaytarıldı"

    RUNNING_STATUSES = (Status.VALIDATING, Status.IMPORTING, Status.ROLLING_BACK)

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    source_type = models.CharField(max_length=10, choices=Source.choices)
    original_filename = models.CharField(max_length=255, blank=True)
    # Yer tutmasın deyə fayl yalnız ən son import üçün saxlanılır
    file = models.FileField(upload_to="customer_imports/%Y/%m/", null=True, blank=True, max_length=500)
    file_sha256 = models.CharField(max_length=64, blank=True, db_index=True)
    file_size = models.BigIntegerField(default=0)

    status = models.CharField(max_length=20, choices=Status.choices, default=Status.VALIDATING, db_index=True)
    phase = models.CharField(max_length=120, blank=True)
    progress_total = models.IntegerField(default=0)
    progress_done = models.IntegerField(default=0)

    total_rows = models.IntegerField(default=0)
    new_count = models.IntegerField(default=0)
    existing_count = models.IntegerField(default=0)
    duplicate_in_file_count = models.IntegerField(default=0)
    problem_count = models.IntegerField(default=0)
    warning_count = models.IntegerField(default=0)
    created_count = models.IntegerField(default=0)

    # Fayl səviyyəsində qeydlər (tanınmayan sütunlar, yaradılacaq regionlar və s.)
    summary = models.JSONField(default=dict, blank=True)
    # Bu importun yaratdığı region / avadanlıq / optik qutu id-ləri (geri qaytarmada lazımdır)
    created_refs = models.JSONField(default=dict, blank=True)
    rollback_summary = models.JSONField(default=dict, blank=True)
    error_message = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="customer_import_batches",
    )
    confirmed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+",
    )
    rolled_back_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    rolled_back_at = models.DateTimeField(null=True, blank=True)
    heartbeat_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.original_filename} ({self.get_status_display()})"


class CustomerImportRow(models.Model):
    """Fayldakı bir sətir və onun nəticəsi (tarixçə üçün həmişə saxlanılır)."""

    class Result(models.TextChoices):
        NEW = "new", "Yeni (yaradılacaq)"
        CREATED = "created", "Yaradıldı"
        EXISTING = "existing", "Artıq mövcuddur"
        DUPLICATE_IN_FILE = "duplicate_in_file", "Faylda təkrar"
        PROBLEM = "problem", "Problemli"

    batch = models.ForeignKey(CustomerImportBatch, on_delete=models.CASCADE, related_name="rows")
    row_number = models.IntegerField()
    raw = models.JSONField(default=dict, blank=True)        # fayldakı orijinal dəyərlər
    data = models.JSONField(default=dict, blank=True)       # təmizlənmiş, yaradılacaq dəyərlər
    keys = models.JSONField(default=list, blank=True)       # nömrə müqayisə açarları
    result = models.CharField(max_length=20, choices=Result.choices, db_index=True)
    reasons = models.JSONField(default=list, blank=True)    # [{code, message}]
    warnings = models.JSONField(default=list, blank=True)   # [{code, message}]
    matches = models.JSONField(default=list, blank=True)    # bazadakı uyğun müştərilərin snapshot-u
    duplicate_of_row = models.IntegerField(null=True, blank=True)
    created_customer = models.ForeignKey(
        "tasks.Customer", on_delete=models.SET_NULL, null=True, blank=True, related_name="+",
    )

    class Meta:
        ordering = ["row_number", "id"]
        indexes = [
            models.Index(fields=["batch", "result"]),
            models.Index(fields=["batch", "row_number"]),
        ]

    def __str__(self):
        return f"{self.batch_id} #{self.row_number} {self.result}"
