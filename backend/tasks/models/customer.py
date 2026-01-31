from django.db import models
from users.models import Region


class Customer(models.Model):
    """Customer model for task assignments."""
    full_name = models.CharField(max_length=200)
    register_number = models.CharField(max_length=60, blank=True)
    phone_number = models.CharField(max_length=30, blank=True)
    passport_image = models.ImageField(upload_to="customers/passports/", null=True, blank=True)
    
    region = models.ForeignKey(Region, on_delete=models.PROTECT, related_name="customers")
    address = models.CharField(max_length=255, blank=True)
    address_coordinates = models.JSONField(default=dict, blank=True)  # {"lat":..., "lng":...}
    
    is_active = models.BooleanField(default=True)  # Soft delete
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return self.full_name
