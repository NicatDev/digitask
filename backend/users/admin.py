from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, Role, Region, Group, UserLocation, LocationHistory

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'email', 'role', 'is_active', 'address', 'address_coordinates')
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Custom Fields', {'fields': ('role', 'address', 'address_coordinates')}),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Custom Fields', {'fields': ('role', 'address', 'address_coordinates')}),
    )

admin.site.register(Role)
admin.site.register(Region)
admin.site.register(Group)
admin.site.register(UserLocation)
admin.site.register(LocationHistory)