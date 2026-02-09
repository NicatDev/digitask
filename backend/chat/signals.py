from django.db.models.signals import post_save
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Message, GroupMembership

@receiver(post_save, sender=Message)
def message_post_save(sender, instance, created, **kwargs):
    if created:
        channel_layer = get_channel_layer()
        group = instance.group
        sender_user = instance.sender

        # Notify all members of the group except the sender
        members = GroupMembership.objects.filter(group=group).exclude(user=sender_user)
        
        for membership in members:
            user_id = membership.user.id
            async_to_sync(channel_layer.group_send)(
                f'user_notifications_{user_id}',
                {
                    'type': 'notification_message', # Reusing the handler in NotificationConsumer
                    'chat_notification': { # Special payload for chat
                        'group_id': group.id,
                        'message_content': instance.content,
                        'sender_name': sender_user.get_full_name(),
                        'created_at': instance.created_at.isoformat(),
                    }
                }
            )
