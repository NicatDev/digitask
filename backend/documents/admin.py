from django.contrib import admin
from .models import Shelf, TaskDocument


@admin.register(Shelf)
class ShelfAdmin(admin.ModelAdmin):
    list_display = ('name', 'location', 'created_at')
    search_fields = ('name', 'location')


@admin.register(TaskDocument)
class TaskDocumentAdmin(admin.ModelAdmin):
    list_display = ('title', 'task', 'shelf', 'confirmed', 'created_at')
    list_filter = ('confirmed', 'shelf')
    search_fields = ('title',)
