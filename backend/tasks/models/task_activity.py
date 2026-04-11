from django.conf import settings
from django.db import models


class TaskActivity(models.Model):
    """Timeline: comments and automated logs for a task."""

    class Action(models.TextChoices):
        COMMENT = "comment", "Şərh"
        STATUS_CHANGE = "status_change", "Status dəyişdi"
        DOCUMENT_ADDED = "document_added", "Sənəd əlavə olundu"
        PRODUCT_ADDED = "product_added", "Məhsul əlavə olundu"
        SURVEY_SAVED = "survey_saved", "Anket saxlanıldı"
        ASSIGNEE_ADDED = "assignee_added", "İcraçı əlavə olundu"
        TASK_UPDATED = "task_updated", "Tapşırıq yeniləndi"
        TASK_CREATED = "task_created", "Tapşırıq yaradıldı"

    task = models.ForeignKey(
        "tasks.Task",
        on_delete=models.CASCADE,
        related_name="activities",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="task_activities",
    )
    action = models.CharField(max_length=32, choices=Action.choices)
    message = models.TextField(blank=True)
    meta = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["task", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.task_id} {self.action} @{self.created_at}"
