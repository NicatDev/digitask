from django.db.models.signals import post_save
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification

@receiver(post_save, sender=Notification)
def send_notification(sender, instance, created, **kwargs):
    if created:
        channel_layer = get_channel_layer()
        data = {
            'id': instance.id,
            'title': instance.title,
            'message': instance.message,
            'notification_type': instance.notification_type,
            'created_at': instance.created_at.isoformat(),
            'related_task': instance.related_task.id if instance.related_task else None
        }

        # Structure the event message
        event = {
            'type': 'notification_message',
            'notification': data
        }

        if instance.notification_type == Notification.NotificationType.GENERAL:
            async_to_sync(channel_layer.group_send)(
                'general_notifications',
                event
            )
        
        # If it's a task related notification, send to the assignee
        if instance.related_task and instance.related_task.assigned_to:
            user_id = instance.related_task.assigned_to.id
            async_to_sync(channel_layer.group_send)(
                f'user_notifications_{user_id}',
                event
            )
