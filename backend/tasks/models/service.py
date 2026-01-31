from django.db import models


class Service(models.Model):
    """Dynamic service types that can be assigned to tasks."""
    name = models.CharField(max_length=140, unique=True)
    icon = models.CharField(max_length=50, default='AppstoreOutlined')  # Ant Design icon name
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)  # Soft delete

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class Column(models.Model):
    """Dynamic columns/fields for each service type."""

    class FieldType(models.TextChoices):
        STRING = "string", "String"
        TEXT = "text", "Text"
        IMAGE = "image", "Image"
        FILE = "file", "File"
        DATE = "date", "Date"
        DATETIME = "datetime", "Datetime"
        INTEGER = "integer", "Integer"
        DECIMAL = "decimal", "Decimal"
        BOOLEAN = "boolean", "Boolean"

    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name="columns")

    name = models.CharField(max_length=120)
    key = models.SlugField(max_length=60)
    field_type = models.CharField(max_length=20, choices=FieldType.choices)
    required = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)  # Soft delete
    min_value = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)
    max_value = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)

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
