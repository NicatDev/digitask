from rest_framework import serializers
from django.contrib.auth import get_user_model
from ..models import ChatGroup, GroupMembership, Message, MessageReadStatus

User = get_user_model()

class UserSimpleSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'first_name', 'last_name', 'avatar']

class GroupMembershipSerializer(serializers.ModelSerializer):
    user = UserSimpleSerializer(read_only=True)

    class Meta:
        model = GroupMembership
        fields = ['id', 'user', 'joined_at', 'can_send_messages']

class ChatGroupListSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = ChatGroup
        fields = ['id', 'name', 'image', 'last_message', 'unread_count', 'created_at']

    def get_last_message(self, obj):
        last_msg = obj.messages.last()
        if last_msg:
            return {
                'content': last_msg.content,
                'sender': last_msg.sender.get_full_name(),
                'created_at': last_msg.created_at
            }
        return None

    def get_unread_count(self, obj):
        user = self.context['request'].user
        # Logic: Messages in group NOT in MessageReadStatus for this user
        # This can be expensive. Optimized viewset query preference.
        # Fallback here (may cause N+1 if not careful, but fine for prototype)
        return Message.objects.filter(group=obj).exclude(read_statuses__user=user).count()

class ChatGroupDetailSerializer(serializers.ModelSerializer):
    members = GroupMembershipSerializer(source='memberships', many=True, read_only=True)
    owner = UserSimpleSerializer(read_only=True)

    class Meta:
        model = ChatGroup
        fields = ['id', 'name', 'owner', 'image', 'members', 'created_at', 'is_active', 'only_owner_can_send']

class MessageSerializer(serializers.ModelSerializer):
    sender = UserSimpleSerializer(read_only=True)
    is_me = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'group', 'sender', 'content', 'created_at', 'is_me']

    def get_is_me(self, obj):
        request = self.context.get('request')
        if request and request.user:
            return obj.sender == request.user
        return False
