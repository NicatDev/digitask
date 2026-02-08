from django.db import models
from django.contrib.auth import get_user_model
from tasks.models import Task
from .shelf import Shelf
from warehouse.models import StockMovement

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
    stock_movement = models.ForeignKey(
        StockMovement,
        on_delete=models.CASCADE,
        related_name="documents",
        null=True,
        blank=True
    )
    action = models.CharField(max_length=255, blank=True, null=True, help_text="Prosesin açıqlaması")
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
        db_table = 'tasks_taskdocument'
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=["task"]),
            models.Index(fields=["confirmed"]),
            models.Index(fields=["shelf"]),
        ]

    def __str__(self):
        return f"{self.title} - {self.task.title if self.task else 'No Task'}"
