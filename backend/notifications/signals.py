from django.db.models.signals import post_save, m2m_changed
from django.db import transaction
from django.dispatch import receiver
import threading
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .models import Notification
import logging

logger = logging.getLogger(__name__)


def _fcm_thread_entry(notification_id, user_ids, push_metadata):
    """FCM üçün DB-dən təzə instance götürür; push_metadata threaddə bərpa olunur."""
    try:
        n = Notification.objects.get(pk=notification_id)
    except Notification.DoesNotExist:
        return
    send_notification_fcm(n, user_ids, push_metadata=push_metadata)


def send_notification_ws(instance, target_users=None, push_metadata=None):
    channel_layer = get_channel_layer()
    task_id = instance.related_task_id
    register_number = None
    if task_id:
        try:
            from tasks.models import Task

            t = Task.objects.select_related('customer').filter(pk=task_id).first()
            if t and t.customer_id:
                register_number = (t.customer.register_number or '').strip() or None
        except Exception:
            register_number = None
    data = {
        'id': instance.id,
        'title': instance.title,
        'message': instance.message,
        'notification_type': instance.notification_type,
        'created_at': instance.created_at.isoformat(),
        'related_task': task_id,
        'task_register_number': register_number,
    }
    md = push_metadata if push_metadata is not None else getattr(instance, '_push_metadata', None)
    if md:
        for key, val in md.items():
            data[key] = '' if val is None else str(val)
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


def send_notification_fcm(instance, target_users=None, push_metadata=None):
    """Send FCM push notification alongside WebSocket."""
    from .firebase import send_fcm_to_users, send_fcm_to_all

    fcm_data = {
        'type': 'notification',
        'notification_id': str(instance.id),
        'notification_type': instance.notification_type,
    }
    md = push_metadata if push_metadata is not None else getattr(instance, '_push_metadata', None)
    if md:
        for key, val in md.items():
            fcm_data[key] = '' if val is None else str(val)

    if instance.notification_type == Notification.NotificationType.CHAT_MESSAGE:
        mid = fcm_data.get('chat_message_id') or str(instance.id)
        fcm_data['tag'] = f'digitask-chat-msg-{mid}'
    elif instance.related_task_id:
        fcm_data['task_id'] = str(instance.related_task_id)
        fcm_data['tag'] = f'digitask-task-{instance.related_task_id}-{instance.notification_type}'
        try:
            from tasks.models import Task

            t = Task.objects.select_related('customer').filter(pk=instance.related_task_id).first()
            if t and t.customer_id:
                rn = (t.customer.register_number or '').strip()
                if rn:
                    fcm_data['register_number'] = rn
        except Exception:
            pass
    else:
        # Eyni məntiqi bildirişin tray-da təkrarlanmasının qarşısı (ümumi / tədbir)
        fcm_data['tag'] = f'digitask-{instance.notification_type}-{instance.id}'

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


def _broadcast_general_if_still_untargeted(notification_id):
    """
    Send general WS + FCM only if nobody was targeted before commit.
    Avoids duplicate delivery when create() is followed by target_users.set()
    in the same transaction (e.g. task completed → assignees only).
    """
    try:
        n = Notification.objects.get(pk=notification_id)
    except Notification.DoesNotExist:
        return
    if n.target_users.exists():
        return
    send_notification_ws(n, target_users=None)
    threading.Thread(target=send_notification_fcm, args=(n, None)).start()


@receiver(post_save, sender=Notification)
def broadcast_notification_on_create(sender, instance, created, **kwargs):
    """Broadcast notification via WS+FCM when created without target_users.
    If target_users are added in the same DB transaction, the on-commit check
    skips this broadcast; notification_targets_changed handles targeted delivery.
    """
    if created and not instance.target_users.exists():
        nid = instance.pk
        transaction.on_commit(lambda n_id=nid: _broadcast_general_if_still_untargeted(n_id))


@receiver(m2m_changed, sender=Notification.target_users.through)
def notification_targets_changed(sender, instance, action, pk_set, **kwargs):
    """Send websocket + FCM notification when target_users are added."""
    if action == "post_add" and pk_set:
        meta = getattr(instance, '_push_metadata', None)
        send_notification_ws(instance, target_users=pk_set, push_metadata=meta)
        nid = instance.pk
        uids = list(pk_set)
        transaction.on_commit(
            lambda: threading.Thread(
                target=_fcm_thread_entry,
                args=(nid, uids, meta),
            ).start()
        )


from tasks.models import Task
from django.contrib.auth import get_user_model

from .services import send_notification
from .task_helpers import format_task_line, task_with_customer, user_ids_assignee_change_recipients

User = get_user_model()


@receiver(m2m_changed, sender=Task.assigned_to.through)
def task_assignment_changed(sender, instance, action, pk_set, **kwargs):
    """İcraçı əlavəsi: qrupdakı imtiyazlılar + bütün icraçılar (təkrar bildiriş əngəlli)."""
    if action == "post_add":
        # Any join/add should immediately move TODO tasks to IN_PROGRESS.
        if instance.status == Task.Status.TODO:
            Task.objects.filter(pk=instance.pk, status=Task.Status.TODO).update(
                status=Task.Status.IN_PROGRESS
            )
            instance.status = Task.Status.IN_PROGRESS

    if action == "post_add" and pk_set:
        task = task_with_customer(instance)
        recipient_ids = user_ids_assignee_change_recipients(task)
        if not recipient_ids:
            return
        line = format_task_line(task)
        send_notification(
            title="Tapşırığa icraçı əlavə olundu",
            message=f"{line}\n{task.title}",
            notification_type=Notification.NotificationType.TASK_ASSIGNED,
            related_task=task,
            target_user_ids=recipient_ids,
            dedupe_seconds=45,
        )

    if action in {"post_remove", "post_clear"}:
        # If all assignees are removed, task must return to TODO.
        if not instance.assigned_to.exists() and instance.status != Task.Status.TODO:
            Task.objects.filter(pk=instance.pk).update(
                status=Task.Status.TODO,
                rescheduled_date=None,
            )
