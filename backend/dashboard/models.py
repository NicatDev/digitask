from django.db import models
from django.utils import timezone

class Event(models.Model):
    class Type(models.TextChoices):
        MEETING = 'meeting', 'İclat'
        HOLIDAY = 'holiday', 'Bayram'
        MAINTENANCE = 'maintenance', 'Texniki işlər'
        OTHER = 'other', 'Digər'
        ANNOUNCEMENT = 'announcement', 'Elan'

    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    event_type = models.CharField(max_length=20, choices=Type.choices, default=Type.ANNOUNCEMENT)
    date = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    class Meta:
        ordering = ['-date']
