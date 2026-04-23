from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .models import Notification


def send_notification(
    title,
    message,
    notification_type='general',
    related_task=None,
    target_user_ids=None,
    dedupe_seconds=0,
    push_metadata=None,
):
    """
    Create notification.
    Broadcasting is handled by signals in notifications/signals.py

    target_user_ids: optional iterable of user primary keys. When set (same transaction
    as create), only those users receive WS/FCM; all-users broadcast is skipped.
    Omit for general notifications (e.g. dashboard).

    dedupe_seconds: əgər > 0, eyni növ + başlıq üçün bu müddətdə artıq bildiriş varsa
    (tapşırıqlı: eyni related_task; ümumi: related_task boş), yenisi yaradılmır.

    push_metadata: DB-yə yazılmır; WebSocket və FCM data üçün əlavə açarlar (məs. group_id).
    """
    if dedupe_seconds:
        since = timezone.now() - timedelta(seconds=int(dedupe_seconds))
        q = Notification.objects.filter(
            notification_type=notification_type,
            title=title,
            created_at__gte=since,
        )
        if related_task is not None:
            q = q.filter(related_task_id=related_task.pk)
        else:
            q = q.filter(related_task__isnull=True)
        existing = q.order_by('-created_at').first()
        if existing:
            return existing

    # Wrap in atomic so that post_save on_commit fires AFTER target_users.set().
    # Without this, Django autocommit commits create() immediately, on_commit
    # runs before target_users.set(), sees empty targets and broadcasts to ALL
    # users (including the sender) — causing duplicates + self-notifications.
    with transaction.atomic():
        notification = Notification.objects.create(
            title=title,
            message=message,
            notification_type=notification_type,
            related_task=related_task,
        )
        if push_metadata:
            notification._push_metadata = push_metadata
        if target_user_ids is not None:
            notification.target_users.set(target_user_ids)

    return notification
