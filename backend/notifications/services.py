from .models import Notification

def send_notification(title, message, notification_type='general', related_task=None):
    """
    Create notification.
    Broadcasting is handled by post_save signal in tasks/signals.py
    """
    notification = Notification.objects.create(
        title=title,
        message=message,
        notification_type=notification_type,
        related_task=related_task
    )
    
    return notification
