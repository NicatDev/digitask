from django.db import models
from django.contrib.auth.models import AbstractUser

class Role(models.Model):
    name = models.CharField(max_length=80, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    # Permission flags (as per user input)
    is_task_reader = models.BooleanField(default=False)
    is_task_writer = models.BooleanField(default=False)

    is_document_reader = models.BooleanField(default=False)
    is_document_writer = models.BooleanField(default=False)

    is_warehouse_reader = models.BooleanField(default=False)
    is_warehouse_writer = models.BooleanField(default=False)

    is_admin = models.BooleanField(default=False)
    is_super_admin = models.BooleanField(default=False)

    def __str__(self):
        return self.name

class User(AbstractUser):
    role = models.ForeignKey(Role, on_delete=models.SET_NULL, null=True, blank=True, related_name="users")
    group = models.ForeignKey('users.Group', on_delete=models.SET_NULL, null=True, blank=True, related_name="users")
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    address = models.CharField(max_length=255, blank=True, null=True)
    address_coordinates = models.JSONField(blank=True, null=True)
    # Soft delete for User is usually handled by is_active=False
