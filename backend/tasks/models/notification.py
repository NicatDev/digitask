from django.db import models
from django.conf import settings


class Notification(models.Model):
    """Notification model with read tracking per user."""
    
    class NotificationType(models.TextChoices):
        TASK_CREATED = 'task_created', 'Yeni Task'
        TASK_ASSIGNED = 'task_assigned', 'Task Təyin Edildi'
        TASK_COMPLETED = 'task_completed', 'Task Tamamlandı'
        GENERAL = 'general', 'Ümumi'
    
    title = models.CharField(max_length=255)
    message = models.TextField(blank=True)
    notification_type = models.CharField(
        max_length=20,
        choices=NotificationType.choices,
        default=NotificationType.GENERAL
    )
    related_task = models.ForeignKey(
        'tasks.Task',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    # ManyToMany to track who has read this notification
    read_by = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name='read_notifications'
    )
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.title} ({self.notification_type})"
