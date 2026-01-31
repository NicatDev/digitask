from django.db import models
from django.conf import settings

class UserLocation(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="location_profile")
    latitude = models.DecimalField(max_digits=25, decimal_places=15, null=True, blank=True)
    longitude = models.DecimalField(max_digits=25, decimal_places=15, null=True, blank=True)
    is_online = models.BooleanField(default=False)
    last_seen = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user} Location ({self.is_online})"

class LocationHistory(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="location_history")
    latitude = models.DecimalField(max_digits=25, decimal_places=15)
    longitude = models.DecimalField(max_digits=25, decimal_places=15)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['user', 'timestamp']),
        ]

    def __str__(self):
        return f"{self.user} at {self.timestamp}"
