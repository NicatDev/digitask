from django.db import models
from django.contrib.auth.models import AbstractUser



class Role(models.Model):
    name = models.CharField(max_length=80, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)

    is_task_reader = models.BooleanField(default=False)
    is_task_writer = models.BooleanField(default=False)

    is_warehouse_reader = models.BooleanField(default=False)
    is_warehouse_writer = models.BooleanField(default=False)

    is_admin = models.BooleanField(default=False)
    is_super_admin = models.BooleanField(default=False)

    def __str__(self):
        return self.name


class User(AbstractUser):
    """
    AbstractUser already includes:
    first_name, last_name, username, email, password, etc.
    """
    phone_number = models.CharField(max_length=30, blank=True)
    role = models.ForeignKey(Role, on_delete=models.PROTECT, null=True, blank=True, related_name="users")
    avatar = models.ImageField(upload_to="avatars/", null=True, blank=True)

    def __str__(self):
        return self.username
