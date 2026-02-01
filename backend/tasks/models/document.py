from django.db import models
from django.contrib.auth import get_user_model
from .task import Task
from .shelf import Shelf
from warehouse.models import Warehouse, StockMovement

User = get_user_model()


class TaskDocument(models.Model):
    """Tapşırıq üçün sənədlər/şəkillər"""
    task = models.ForeignKey(
        Task, 
        on_delete=models.CASCADE, 
        related_name="task_documents",
        null=True,
        blank=True
    )
    warehouse = models.ForeignKey(
        Warehouse, 
        on_delete=models.SET_NULL, 
        related_name="task_documents",
        null=True,
        blank=True
    )
    stock_movement = models.ForeignKey(
        StockMovement,
        on_delete=models.CASCADE,
        related_name="documents",
        null=True,
        blank=True
    )
    shelf = models.ForeignKey(
        Shelf,
        on_delete=models.SET_NULL,
        related_name="documents",
        null=True,
        blank=True
    )
    title = models.CharField(max_length=200)
    file = models.FileField(upload_to='task_documents/')
    confirmed = models.BooleanField(default=False)
    confirmed_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name="confirmed_documents",
        null=True,
        blank=True
    )
    confirmed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=["task"]),
            models.Index(fields=["warehouse"]),
            models.Index(fields=["confirmed"]),
            models.Index(fields=["shelf"]),
        ]

    def __str__(self):
        return f"{self.title} - {self.task.title if self.task else 'No Task'}"
