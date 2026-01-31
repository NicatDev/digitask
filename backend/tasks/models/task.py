from django.db import models
from django.conf import settings
from users.models import Group
from .customer import Customer
from .service import Service, Column


class Task(models.Model):
    """Task model for task management."""
    
    class Status(models.TextChoices):
        TODO = "todo", "Gözləyir"
        IN_PROGRESS = "in_progress", "İcrada"
        ARRIVED = "arrived", "Çatdı"
        DONE = "done", "Tamamlandı"
        PENDING = "pending", "Təxirə salındı"
        REJECTED = "rejected", "Rədd edildi"
    
    customer = models.ForeignKey(Customer, on_delete=models.PROTECT, related_name="tasks")
    title = models.CharField(max_length=255)
    note = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.TODO)
    
    # Map coordinates
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.SET_NULL, 
        related_name="assigned_tasks", 
        null=True, 
        blank=True
    )
    group = models.ForeignKey(Group, on_delete=models.PROTECT, related_name="tasks")
    
    is_active = models.BooleanField(default=True)  # Soft delete
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['customer']),
            models.Index(fields=['assigned_to']),
            models.Index(fields=['group']),
        ]
    
    def __str__(self):
        return self.title


class TaskService(models.Model):
    """Links a Task to a Service with its dynamic column values."""
    task = models.ForeignKey(Task, on_delete=models.CASCADE, related_name="task_services")
    service = models.ForeignKey(Service, on_delete=models.PROTECT, related_name="task_services")
    note = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ("task", "service")
        indexes = [
            models.Index(fields=["task"]),
            models.Index(fields=["service"]),
        ]
    
    def __str__(self):
        return f"{self.task.title} - {self.service.name}"


def task_service_upload_path(instance, filename):
    """Generate upload path for task service files."""
    ts = instance.task_service
    return f"tasks/{ts.task_id}/services/{ts.service_id}/{instance.column.key}/{filename}"


class TaskServiceValue(models.Model):
    """Dynamic column values for TaskService."""
    task_service = models.ForeignKey(TaskService, on_delete=models.CASCADE, related_name="values")
    column = models.ForeignKey(Column, on_delete=models.PROTECT, related_name="task_values")
    
    # Typed value fields
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
        ]
    
    def get_value(self):
        """Return the appropriate value based on column type."""
        field_map = {
            'string': self.charfield_value,
            'text': self.text_value,
            'image': self.image_value.url if self.image_value else None,
            'file': self.file_value.url if self.file_value else None,
            'date': self.date_value,
            'datetime': self.datetime_value,
            'integer': self.number_value,
            'decimal': self.decimal_value,
            'boolean': self.boolean_value,
        }
        return field_map.get(self.column.field_type)
    
    def __str__(self):
        return f"{self.task_service} - {self.column.key}"
