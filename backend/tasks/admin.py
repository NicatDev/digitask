from django.contrib import admin
from .models import TaskType, Task

@admin.register(TaskType)
class TaskTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'color', 'is_active', 'created_at')
    search_fields = ('name',)
    list_filter = ('is_active',)

admin.site.register(Task)