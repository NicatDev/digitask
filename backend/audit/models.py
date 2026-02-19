from django.db import models
from django.conf import settings

class AuditLog(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=50)  # e.g., "CREATE", "UPDATE", "DELETE", "POST"
    method = models.CharField(max_length=10, null=True, blank=True)   # HTTP Method
    path = models.CharField(max_length=255, null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    payload = models.JSONField(null=True, blank=True)
    
    # New Fields
    resource_type = models.CharField(max_length=100, null=True, blank=True) # e.g. "Task", "User"
    resource_id = models.CharField(max_length=100, null=True, blank=True)
    changes = models.JSONField(null=True, blank=True) # { "field": { "old": "X", "new": "Y" } }
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user} - {self.action} - {self.resource_type} - {self.created_at}"
