from django.db.models.signals import post_save
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Message, GroupMembership
from notifications.models import Notification
from notifications.services import send_notification


TASK_PREFIX = '[[DIGITASK_TASK_V1:'
TASK_SUFFIX = ']]'


def chat_message_preview(content):
    text = (content or '').strip()
    if text.startswith(TASK_PREFIX) and text.endswith(TASK_SUFFIX):
        return 'Tapşırıq göndərildi'
    return text


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
                    'type': 'notification_message',  # Reusing the handler in NotificationConsumer
                    'chat_notification': {
                        'group_id': group.id,
                        'message_content': chat_message_preview(instance.content),
                        'sender_name': sender_user.get_full_name(),
                        'created_at': instance.created_at.isoformat(),
                    },
                },
            )

        recipient_ids = list(members.values_list('user_id', flat=True))
        if recipient_ids:
            sender_name = (sender_user.get_full_name() or '').strip() or (
                sender_user.username or 'İstifadəçi'
            )
            title = f"{group.name}: {sender_name}"[:255]
            body = chat_message_preview(instance.content)
            if len(body) > 500:
                body = body[:497] + '...'
            send_notification(
                title=title,
                message=body,
                notification_type=Notification.NotificationType.CHAT_MESSAGE,
                related_task=None,
                target_user_ids=recipient_ids,
                dedupe_seconds=0,
                push_metadata={
                    'group_id': str(group.id),
                    'chat_message_id': str(instance.pk),
                },
            )
