from django.contrib import admin
from .models import Event

@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'event_type', 'date', 'is_active')
    search_fields = ('title', 'description')
    list_filter = ('event_type', 'date', 'is_active')
    list_per_page = 20
    date_hierarchy = 'date'
