from django.contrib import admin
from .models import (
    TaskType,
    Task,
    TaskActivity,
    Customer,
    Service,
    Column,
    TaskService,
    TaskServiceValue,
    Equipment,
    OpticBox,
)

class TaskServiceValueInline(admin.TabularInline):
    model = TaskServiceValue
    extra = 0
    can_delete = False

class TaskServiceInline(admin.TabularInline):
    model = TaskService
    extra = 0
    show_change_link = True

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active', 'created_at')
    search_fields = ('name', 'description')
    list_filter = ('is_active',)
    list_per_page = 20


@admin.register(OpticBox)
class OpticBoxAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active', 'created_at')
    search_fields = ('name', 'description')
    list_filter = ('is_active',)
    list_per_page = 20


@admin.register(TaskActivity)
class TaskActivityAdmin(admin.ModelAdmin):
    list_display = ('task', 'action', 'user', 'created_at')
    list_filter = ('action', 'created_at')
    search_fields = ('message', 'task__title')
    raw_id_fields = ('task', 'user')
    date_hierarchy = 'created_at'


@admin.register(TaskType)
class TaskTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'color', 'is_active', 'created_at')
    search_fields = ('name',)
    list_filter = ('is_active', 'created_at')
    list_per_page = 20

@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = (
        'full_name', 'register_number', 'phone_number', 'region',
        'equipment', 'optic_box', 'is_active', 'created_at',
    )
    search_fields = ('full_name', 'register_number', 'phone_number', 'address')
    list_filter = ('region', 'equipment', 'optic_box', 'is_active', 'created_at')
    list_per_page = 20
    date_hierarchy = 'created_at'

@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'customer', 'status', 'group', 'task_type', 'created_at', 'updated_at')
    search_fields = ('title', 'customer__full_name', 'customer__register_number', 'customer__phone_number', 'note')
    list_filter = ('status', 'group', 'task_type', 'customer__region', 'assigned_to', 'created_at', 'is_active')
    inlines = [TaskServiceInline]
    filter_horizontal = ('assigned_to', 'services')
    list_per_page = 20
    date_hierarchy = 'created_at'

@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = ('name', 'icon', 'is_active')
    search_fields = ('name', 'description')
    list_filter = ('is_active',)
    list_per_page = 20

@admin.register(Column)
class ColumnAdmin(admin.ModelAdmin):
    list_display = ('name', 'key', 'service', 'field_type', 'required', 'is_active')
    search_fields = ('name', 'key', 'service__name')
    list_filter = ('service', 'field_type', 'required', 'is_active')
    list_per_page = 20

@admin.register(TaskService)
class TaskServiceAdmin(admin.ModelAdmin):
    list_display = ('task', 'service', 'created_at')
    search_fields = ('task__title', 'service__name')
    list_filter = ('service', 'created_at')
    inlines = [TaskServiceValueInline]
    list_per_page = 20
    date_hierarchy = 'created_at'

@admin.register(TaskServiceValue)
class TaskServiceValueAdmin(admin.ModelAdmin):
    list_display = ('task_service', 'column', 'get_value')
    search_fields = ('task_service__task__title', 'column__name', 'charfield_value', 'text_value')
    list_filter = ('column__service', 'column__field_type')
    list_per_page = 50