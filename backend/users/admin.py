from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Role, Region, Group, UserLocation, LocationHistory

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'email', 'role', 'group', 'is_active', 'phone_number', 'date_joined')
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Custom Fields', {'fields': ('role', 'group', 'phone_number', 'avatar', 'address', 'address_coordinates')}),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Custom Fields', {'fields': ('role', 'group', 'phone_number', 'avatar', 'address', 'address_coordinates')}),
    )
    search_fields = ('username', 'email', 'first_name', 'last_name', 'phone_number')
    list_filter = ('role', 'group', 'is_active', 'is_staff', 'date_joined')
    list_per_page = 20
    date_hierarchy = 'date_joined'

@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ('name', 'description', 'is_active')
    search_fields = ('name', 'description')
    list_filter = ('is_active',)
    list_per_page = 20

@admin.register(Group)
class GroupAdmin(admin.ModelAdmin):
    list_display = ('name', 'region', 'description', 'is_active')
    search_fields = ('name', 'region__name', 'description')
    list_filter = ('region', 'is_active')
    list_per_page = 20

@admin.register(Region)
class RegionAdmin(admin.ModelAdmin):
    list_display = ('name', 'is_active')
    search_fields = ('name',)
    list_filter = ('is_active',)
    list_per_page = 20

@admin.register(UserLocation)
class UserLocationAdmin(admin.ModelAdmin):
    list_display = ('user', 'is_online', 'last_seen')
    search_fields = ('user__username', 'user__email')
    list_filter = ('is_online', 'last_seen')
    list_per_page = 50
    date_hierarchy = 'last_seen'

@admin.register(LocationHistory)
class LocationHistoryAdmin(admin.ModelAdmin):
    list_display = ('user', 'timestamp', 'latitude', 'longitude')
    search_fields = ('user__username', 'user__email')
    list_filter = ('timestamp',)
    list_per_page = 50
    date_hierarchy = 'timestamp'