from django.conf import settings
from django.db import models


def support_attachment_upload_path(instance, filename):
    return f"support/{instance.created_by_id}/{filename}"


class SupportRequest(models.Model):
    class Status(models.TextChoices):
        NEW = "new", "Yeni"
        ACCEPTED = "accepted", "Qəbul edildi"
        REJECTED = "rejected", "Rədd edildi"
        DONE = "done", "Done"
        SOLVED = "solved", "Həll edildi"
        CLOSED = "closed", "Bağlandı"

    title = models.CharField(max_length=255)
    summary = models.TextField()
    current_state = models.TextField()
    expected_state = models.TextField()
    attachment = models.FileField(upload_to=support_attachment_upload_path, blank=True, null=True)
    status = models.CharField(max_length=24, choices=Status.choices, default=Status.NEW)
    reject_note = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="support_requests",
    )
    accepted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="accepted_support_requests",
        null=True,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["created_by"]),
            models.Index(fields=["-created_at"]),
        ]

    def __str__(self):
        return f"#{self.pk} {self.title}"


class SupportComment(models.Model):
    support_request = models.ForeignKey(
        SupportRequest,
        on_delete=models.CASCADE,
        related_name="comments",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="support_comments",
    )
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [models.Index(fields=["support_request", "created_at"])]

    def __str__(self):
        return f"{self.support_request_id} by {self.user_id}"
