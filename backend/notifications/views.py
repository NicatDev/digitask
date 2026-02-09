from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Notification
from .serializers import NotificationSerializer


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
