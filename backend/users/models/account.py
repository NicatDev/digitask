from django.db import models
from django.contrib.auth.models import AbstractUser

class Role(models.Model):
    name = models.CharField(max_length=80, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    # Permission flags (as per user input)
    is_task_reader = models.BooleanField(default=False)
    is_task_writer = models.BooleanField(default=False)
    is_task_view_all = models.BooleanField(default=False)

    is_document_reader = models.BooleanField(default=False)
    is_document_writer = models.BooleanField(default=False)

    is_warehouse_reader = models.BooleanField(default=False)
    is_warehouse_writer = models.BooleanField(default=False)

    is_admin = models.BooleanField(default=False)
    is_super_admin = models.BooleanField(default=False)

    class Meta:
        ordering = ['name', 'id']

    def __str__(self):
        return self.name

class User(AbstractUser):
    role = models.ForeignKey(Role, on_delete=models.SET_NULL, null=True, blank=True, related_name="users")
    group = models.ForeignKey('users.Group', on_delete=models.SET_NULL, null=True, blank=True, related_name="users")
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    address = models.CharField(max_length=255, blank=True, null=True)
    address_coordinates = models.JSONField(blank=True, null=True)
    # Tapşırıq cədvəli: sütun açarı → görünür (true/false). Migration sizin tərəfinizdən.
    task_table_column_visibility = models.JSONField(default=dict, blank=True)
    # Soft delete for User is usually handled by is_active=False


class UserFcmDevice(models.Model):
    """İstifadəçi başına platform üzrə bir FCM token (web, android, ios)."""

    class Platform(models.TextChoices):
        WEB = 'web', 'Web'
        ANDROID = 'android', 'Android'
        IOS = 'ios', 'iOS'
        UNKNOWN = 'unknown', 'Naməlum'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='fcm_devices')
    platform = models.CharField(max_length=16, choices=Platform.choices, default=Platform.UNKNOWN)
    token = models.CharField(max_length=512)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user', 'platform'], name='unique_user_fcm_platform'),
        ]
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['token']),
        ]

    def __str__(self):
        return f'{self.user_id} {self.platform}'
