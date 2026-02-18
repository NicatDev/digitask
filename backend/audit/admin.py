from django.contrib import admin
from .models import AuditLog

@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('created_at', 'user', 'action', 'method', 'path', 'ip_address')
    list_filter = ('action', 'method', 'created_at')
    search_fields = ('path', 'user__email', 'user__first_name', 'user__last_name', 'payload')
    readonly_fields = ('created_at', 'action', 'method', 'path', 'ip_address', 'user', 'payload')
    list_per_page = 50
    date_hierarchy = 'created_at'
