from django.contrib import admin
from .models import Event, EventImage


class EventImageInline(admin.TabularInline):
    model = EventImage
    extra = 0


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ('title', 'event_type', 'date', 'is_active', 'created_at')
    search_fields = ('title', 'description')
    list_filter = ('event_type', 'date', 'is_active')
    list_per_page = 20
    date_hierarchy = 'date'
    ordering = ('-created_at',)
    inlines = [EventImageInline]
