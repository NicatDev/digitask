from django.contrib import admin
from .models import Notification

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('title', 'notification_type', 'related_task', 'created_at')
    list_filter = ('notification_type', 'created_at')
    search_fields = ('title', 'message', 'related_task__title')
    filter_horizontal = ('read_by',)
    list_per_page = 50
    date_hierarchy = 'created_at'
