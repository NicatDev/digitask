from django.db.models.signals import post_save, m2m_changed
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification

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
    elif instance.notification_type == Notification.NotificationType.GENERAL:
        async_to_sync(channel_layer.group_send)(
            'general_notifications',
            event
        )

@receiver(post_save, sender=Notification)
def notification_post_save(sender, instance, created, **kwargs):
    """
    Signal to send websocket notification when a Notification object is created WITHOUT target users.
    If it has target_users, the m2m_changed signal will handle it instead.
    """
    # Only process completely new GENERAL notifications that might not hit m2m_changed
    if created and instance.notification_type == Notification.NotificationType.GENERAL:
        # We don't know if target_users will be populated yet, but if it's GENERAL and 
        # meant for everyone, we can broadcast it. If it's targeted, m2m_changed takes over.
        # To avoid duplicate sends on pure GENERAL, we check if it's being sent from dashboard event creation.
        # Actually, if target_users is meant to be empty for GENERAL, this is the only place it fires.
        pass # Better to let the caller explicitly set target_users or leave it for generic broadcasting.

# Note: Django's related manager doesn't trigger m2m_changed if it's empty during creation.
# So we need a comprehensive way to broadcast. Let's send on post_save for GENERAL and m2m for TARGETED.

@receiver(post_save, sender=Notification)
def broadcast_general_notification(sender, instance, created, **kwargs):
    if created and instance.notification_type == Notification.NotificationType.GENERAL:
         send_notification_ws(instance, target_users=None)

@receiver(m2m_changed, sender=Notification.target_users.through)
def notification_targets_changed(sender, instance, action, pk_set, **kwargs):
    """
    Signal to send websocket notification when target_users are added to a Notification.
    """
    if action == "post_add" and pk_set:
        send_notification_ws(instance, target_users=pk_set)

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
            # Notification created without target_users -> broadcasted as general via broadcast_general_notification signal
        else:
            # Rule 2: There were already assignees. Send targeted to all of them.
            notification = Notification.objects.create(
                title="Tapşırığa yeni icraçı əlavə olundu",
                message=f"{instance.title} tapşırığına əlavə icraçı(lar) təyin edildi.",
                notification_type=Notification.NotificationType.TASK_ASSIGNED,
                related_task=instance
            )
            # Adding target_users triggers notification_targets_changed which broadcasts via WebSocket
            notification.target_users.set(instance.assigned_to.all())
