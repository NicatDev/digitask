from django.contrib import admin
from .models import ChatGroup, GroupMembership, Message, MessageReadStatus

class GroupMembershipInline(admin.TabularInline):
    model = GroupMembership
    extra = 0

@admin.register(ChatGroup)
class ChatGroupAdmin(admin.ModelAdmin):
    list_display = ('name', 'owner', 'created_at', 'is_active')
    search_fields = ('name', 'owner__username', 'owner__email')
    list_filter = ('is_active', 'created_at', 'owner')
    inlines = [GroupMembershipInline]
    list_per_page = 20
    date_hierarchy = 'created_at'

@admin.register(GroupMembership)
class GroupMembershipAdmin(admin.ModelAdmin):
    list_display = ('group', 'user', 'joined_at')
    search_fields = ('group__name', 'user__username', 'user__first_name')
    list_filter = ('joined_at', 'group')
    list_per_page = 50
    date_hierarchy = 'joined_at'

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'group', 'created_at', 'content_preview')
    search_fields = ('content', 'sender__username', 'sender__first_name', 'group__name')
    list_filter = ('created_at', 'group')
    list_per_page = 50
    date_hierarchy = 'created_at'
    
    def content_preview(self, obj):
        return obj.content[:50]

@admin.register(MessageReadStatus)
class MessageReadStatusAdmin(admin.ModelAdmin):
    list_display = ('user', 'message', 'read_at')
    search_fields = ('user__username', 'message__content')
    list_filter = ('read_at',)
    list_per_page = 50
    date_hierarchy = 'read_at'
