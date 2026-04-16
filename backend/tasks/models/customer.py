from django.db import models
import uuid
from users.models import Region
from .equipment import Equipment, OpticBox


class Customer(models.Model):
    """Customer model for task assignments."""
    full_name = models.CharField(max_length=200)
    register_number = models.CharField(max_length=60, blank=True)
    phone_number = models.CharField(max_length=30, blank=True)
    passport_image = models.ImageField(upload_to="customers/passports/", null=True, blank=True)
    
    region = models.ForeignKey(Region, on_delete=models.PROTECT, related_name="customers")
    equipment = models.ForeignKey(
        Equipment,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="customers",
    )
    optic_box = models.ForeignKey(
        OpticBox,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="customers",
    )
    address = models.CharField(max_length=255, blank=True)
    address_coordinates = models.JSONField(default=dict, blank=True)  # {"lat":..., "lng":...}
    bulk_created = models.BooleanField(default=False)
    
    is_active = models.BooleanField(default=True)  # Soft delete
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return self.full_name


class CustomerImportJob(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        RUNNING = "running", "Running"
        DONE = "done", "Done"
        FAILED = "failed", "Failed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    total_rows = models.IntegerField(default=0)
    processed_rows = models.IntegerField(default=0)
    created_count = models.IntegerField(default=0)
    skipped_count = models.IntegerField(default=0)
    error_count = models.IntegerField(default=0)
    sample_errors = models.JSONField(default=list, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    duration_ms = models.BigIntegerField(default=0)
    triggered_by = models.ForeignKey(
        "users.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="customer_import_jobs",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
