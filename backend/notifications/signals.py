from django.db.models.signals import post_save, m2m_changed
from django.db import transaction
from django.dispatch import receiver
import threading
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification
import logging

logger = logging.getLogger(__name__)


def send_notification_ws(instance, target_users=None):
    channel_layer = get_channel_layer()
    data = {
        'id': instance.id,
        'title': instance.title,
        'message': instance.message,
        'notification_type': instance.notification_type,
        'created_at': instance.created_at.isoformat(),
        'related_task': instance.related_task.id if instance.related_task else None
    }
    event = {
        'type': 'notification_message',
        'notification': data
    }

    if target_users:
        for user_id in target_users:
            async_to_sync(channel_layer.group_send)(
                f'user_notifications_{user_id}',
                event
            )
    else:
        # Broadcast to all connected users via general notifications channel
        async_to_sync(channel_layer.group_send)(
            'general_notifications',
            event
        )


def send_notification_fcm(instance, target_users=None):
    """Send FCM push notification alongside WebSocket."""
    from .firebase import send_fcm_to_users, send_fcm_to_all

    fcm_data = {
        'type': 'notification',
        'notification_id': str(instance.id),
        'notification_type': instance.notification_type,
    }
    if instance.related_task:
        fcm_data['task_id'] = str(instance.related_task.id)

    try:
        if target_users:
            send_fcm_to_users(
                list(target_users),
                instance.title,
                instance.message,
                data=fcm_data
            )
        else:
            # General notification → send to all
            send_fcm_to_all(
                instance.title,
                instance.message,
                data=fcm_data
            )
    except Exception as e:
        logger.error('FCM notification error: %s', e)


@receiver(post_save, sender=Notification)
def broadcast_notification_on_create(sender, instance, created, **kwargs):
    """Broadcast notification via WS+FCM when created without target_users.
    Notifications WITH target_users are handled by notification_targets_changed signal.
    """
    if created and not instance.target_users.exists():
        send_notification_ws(instance, target_users=None)
        # Run FCM in background thread after transaction commit
        transaction.on_commit(
            lambda: threading.Thread(target=send_notification_fcm, args=(instance, None)).start()
        )


@receiver(m2m_changed, sender=Notification.target_users.through)
def notification_targets_changed(sender, instance, action, pk_set, **kwargs):
    """Send websocket + FCM notification when target_users are added."""
    if action == "post_add" and pk_set:
        send_notification_ws(instance, target_users=pk_set)
        # Run FCM in background thread after transaction commit
        transaction.on_commit(
            lambda: threading.Thread(target=send_notification_fcm, args=(instance, list(pk_set))).start()
        )


from tasks.models import Task
from django.contrib.auth import get_user_model

User = get_user_model()

@receiver(m2m_changed, sender=Task.assigned_to.through)
def task_assignment_changed(sender, instance, action, pk_set, **kwargs):
    """
    Handle task assignment notifications when assignees change.
    Rule 1: If previously no assignees, trigger a GENERAL notification.
    Rule 2: If there were assignees already, trigger a TARGETED notification to existing + new assignees.
    """
    if action == "post_add" and pk_set:
        total_assignees = instance.assigned_to.count()
        new_assignees_count = len(pk_set)

        if total_assignees == new_assignees_count:
            # Rule 1: No previous assignees, this is the first batch
            notification = Notification.objects.create(
                title="Tapşırığa icraçı əlavə olundu",
                message=f"{instance.title} tapşırığına yeni icraçı(lar) təyin edildi.",
                notification_type=Notification.NotificationType.TASK_ASSIGNED,
                related_task=instance
            )
            # TASK_ASSIGNED is not GENERAL, so broadcast_general won't fire.
            # We need to send it explicitly to new assignees.
            notification.target_users.set(instance.assigned_to.all())
        else:
            # Rule 2: There were already assignees. Send targeted to all of them.
            notification = Notification.objects.create(
                title="Tapşırığa yeni icraçı əlavə olundu",
                message=f"{instance.title} tapşırığına əlavə icraçı(lar) təyin edildi.",
                notification_type=Notification.NotificationType.TASK_ASSIGNED,
                related_task=instance
            )
            # Adding target_users triggers notification_targets_changed which broadcasts via WebSocket + FCM
            notification.target_users.set(instance.assigned_to.all())
