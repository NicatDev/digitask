from django.db import models
from django.utils import timezone

class Event(models.Model):
    class Type(models.TextChoices):
        MEETING = 'meeting', 'İclas'
        HOLIDAY = 'holiday', 'Bayram'
        MAINTENANCE = 'maintenance', 'Texniki işlər'
        OTHER = 'other', 'Digər'
        ANNOUNCEMENT = 'announcement', 'Elan'

    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    event_type = models.CharField(max_length=20, choices=Type.choices, default=Type.ANNOUNCEMENT)
    image = models.ImageField(upload_to='events/', null=True, blank=True)
    date = models.DateTimeField(default=timezone.now)
    is_active = models.BooleanField(default=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title

    class Meta:
        # Əvvəlcə yeni əlavə olunan tədbirlər, sonra köhnələr
        ordering = ['-created_at']


class EventImage(models.Model):
    """Tədbirə bir neçə şəkil (köhnə tək `Event.image` sahəsi hələ oxuna bilər)."""

    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='event_images')
    image = models.ImageField(upload_to='events/images/')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['event', '-created_at'])]

    def __str__(self):
        return f'{self.event_id} #{self.pk}'
