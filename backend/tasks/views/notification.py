from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from ..models import Notification
from ..serializers import NotificationSerializer
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync


def send_notification(title, message, notification_type='general', related_task=None):
    """Create notification and broadcast via WebSocket."""
    notification = Notification.objects.create(
        title=title,
        message=message,
        notification_type=notification_type,
        related_task=related_task
    )
    
    # Broadcast to all connected users via channel layer
    try:
        channel_layer = get_channel_layer()
        # We broadcast to a general notifications group
        # Users subscribe to their personal channel in NotificationConsumer
        from users.models import User
        for user in User.objects.filter(is_active=True):
            async_to_sync(channel_layer.group_send)(
                f'user_notifications_{user.id}',
                {
                    'type': 'notification_message',
                    'notification': {
                        'id': notification.id,
                        'title': notification.title,
                        'message': notification.message,
                        'notification_type': notification.notification_type,
                        'created_at': notification.created_at.isoformat()
                    }
                }
            )
    except Exception as e:
        print(f"Failed to broadcast notification: {e}")
    
    return notification


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for notifications - read only with mark-read action."""
    
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        """Return notifications not read by the current user."""
        user = self.request.user
        return Notification.objects.exclude(read_by=user).order_by('-created_at')
    
    @action(detail=False, methods=['post'])
    def mark_read(self, request):
        """Mark all notifications as read for current user."""
        user = request.user
        
        # Get notification IDs from request or mark all
        notification_ids = request.data.get('ids', None)
        
        if notification_ids:
            notifications = Notification.objects.filter(id__in=notification_ids)
        else:
            # Mark all unread as read
            notifications = Notification.objects.exclude(read_by=user)
        
        for notification in notifications:
            notification.read_by.add(user)
        
        return Response({'status': 'marked_as_read', 'count': notifications.count()})
    
    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        """Get count of unread notifications."""
        count = Notification.objects.exclude(read_by=request.user).count()
        return Response({'unread_count': count})
