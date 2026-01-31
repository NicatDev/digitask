from django.db import models
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from core.models import Customer, RegionGroup

class Service(models.Model):
    name = models.CharField(max_length=140, unique=True)
    logo = models.ImageField(upload_to="services/logos/", null=True, blank=True)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name


class Task(models.Model):
    class Status(models.TextChoices):
        TODO = "todo", _("To do")
        IN_PROGRESS = "in_progress", _("In progress")
        ARRIVED = "arrived", _("Arrived")
        DONE = "done", _("Done")
        PENDING = "pending", _("Pending")
        REJECTED = "rejected", _("Rejected")

    title = models.CharField(max_length=255)
    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="tasks")
    note = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.TODO)
    coordinates = models.PointField(srid=4326, null=True, blank=True)
    assigned_to = models.ForeignKey(User, on_delete=models.PROTECT, related_name="tasks", null=True, blank=True)
    group = models.ForeignKey(RegionGroup, on_delete=models.PROTECT, related_name="tasks")

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class TaskService(models.Model):
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="task_services")
    service = models.ForeignKey(Service, on_delete=models.PROTECT, related_name="task_services")

    note = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("task", "service")
        indexes = [models.Index(fields=["task"]), models.Index(fields=["service"])]

    def __str__(self):
        return f"{self.task_id} - {self.service.name}"


class Columns(models.Model):

    class FieldType(models.TextChoices):
        STRING = "string", _("String")
        TEXT = "text", _("Text")
        IMAGE = "image", _("Image")
        FILE = "file", _("File")
        DATE = "date", _("Date")
        DATETIME = "datetime", _("Datetime")
        INTEGER = "integer", _("Integer")
        DECIMAL = "decimal", _("Decimal")
        BOOLEAN = "boolean", _("Boolean")

    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name="columns")

    name = models.CharField(max_length=120)
    key = models.SlugField(max_length=60)
    field_type = models.CharField(max_length=20, choices=FieldType.choices)
    required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    min = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)
    max = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)

    order = models.PositiveIntegerField(default=0)

    class Meta:
        unique_together = ("service", "key")
        ordering = ["order", "id"]
        indexes = [
            models.Index(fields=["service", "key"]),
            models.Index(fields=["service", "field_type"]),
        ]

    def __str__(self):
        return f"{self.service.name}: {self.key} ({self.field_type})"


def task_service_upload_path(instance, filename):
    ts = instance.task_service
    return f"tasks/{ts.task_id}/services/{ts.service_id}/{instance.column.key}/{filename}"


class TaskServiceValues(models.Model):
    """
    TaskService üçün custom dəyərlər (typed columns).
    """
    column = models.ForeignKey(Columns, on_delete=models.PROTECT, related_name="values")
    task_service = models.ForeignKey(TaskService, on_delete=models.CASCADE, related_name="values")

    charfield_value = models.CharField(max_length=255, null=True, blank=True)
    text_value = models.TextField(null=True, blank=True)
    image_value = models.ImageField(upload_to=task_service_upload_path, null=True, blank=True)
    file_value = models.FileField(upload_to=task_service_upload_path, null=True, blank=True)
    date_value = models.DateField(null=True, blank=True)
    datetime_value = models.DateTimeField(null=True, blank=True)

    number_value = models.IntegerField(null=True, blank=True)
    decimal_value = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)

    boolean_value = models.BooleanField(null=True, blank=True)

    class Meta:
        unique_together = ("task_service", "column")
        indexes = [
            models.Index(fields=["task_service"]),
            models.Index(fields=["column"]),
            models.Index(fields=["task_service", "column"]),
        ]

    def clean(self):
        # Column həmin TaskService-in service-inə aid olmalıdır
        if self.column_id and self.task_service_id:
            if self.column.service_id != self.task_service.service_id:
                raise ValidationError({"column": "Bu column bu TaskService-in service-ə aid deyil."})

        filled = {
            "string": bool(self.charfield_value),
            "text": bool(self.text_value),
            "image": bool(self.image_value),
            "file": bool(self.file_value),
            "date": bool(self.date_value),
            "datetime": bool(self.datetime_value),
            "integer": self.number_value is not None,
            "decimal": self.decimal_value is not None,
            "boolean": self.boolean_value is not None,
        }

        if self.column_id:
            expected = self.column.field_type
            true_keys = [k for k, v in filled.items() if v]

            if len(true_keys) > 1:
                raise ValidationError("Yalnız bir value sahəsi doldurula bilər (field_type-a uyğun).")
            if len(true_keys) == 1 and true_keys[0] != expected:
                raise ValidationError(
                    f"Yanlış value sahəsi: column '{expected}' tələb edir, amma '{true_keys[0]}' doldurulub."
                )

            # min/max numeric üçün
            if expected in (Columns.FieldType.INTEGER, Columns.FieldType.DECIMAL):
                val = self.number_value if expected == Columns.FieldType.INTEGER else self.decimal_value
                if val is not None:
                    if self.column.min is not None and val < self.column.min:
                        raise ValidationError("Dəyər minimumdan kiçikdir.")
                    if self.column.max is not None and val > self.column.max:
                        raise ValidationError("Dəyər maksimumdan böyükdür.")

    def __str__(self):
        return f"{self.task_service_id} - {self.column.key}"
