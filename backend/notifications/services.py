from .models import Notification


def send_notification(
    title,
    message,
    notification_type='general',
    related_task=None,
    target_user_ids=None,
):
    """
    Create notification.
    Broadcasting is handled by signals in notifications/signals.py

    target_user_ids: optional iterable of user primary keys. When set (same transaction
    as create), only those users receive WS/FCM; all-users broadcast is skipped.
    Omit for general notifications (e.g. dashboard).
    """
    notification = Notification.objects.create(
        title=title,
        message=message,
        notification_type=notification_type,
        related_task=related_task,
    )
    if target_user_ids is not None:
        notification.target_users.set(target_user_ids)

    return notification
