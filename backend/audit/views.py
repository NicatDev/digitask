from rest_framework import serializers, viewsets, filters, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from .models import AuditLog

class AuditLogSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    user_email = serializers.SerializerMethodField()

    class Meta:
        model = AuditLog
        fields = '__all__'

    def get_user_name(self, obj):
        return obj.user.get_full_name() if obj.user else 'Sistem / Naməlum'

    def get_user_email(self, obj):
        return obj.user.email if obj.user else ''

    ordering_fields = ['created_at']
    ordering = ['-created_at']

from rest_framework.pagination import PageNumberPagination

class AuditLogPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = AuditLogPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = {
        'created_at': ['date', 'gte', 'lte'],
        'method': ['exact'],
        'action': ['exact'],
        'user': ['exact'],
        'resource_type': ['exact'],
    }
    search_fields = ['path', 'payload', 'user__first_name', 'user__last_name', 'user__email']
    ordering_fields = ['created_at']
    ordering = ['-created_at']

    # Resource types excluded from operations view (high-frequency, low-value)
    NOISY_RESOURCE_TYPES = [
        'UserLocation', 'LocationHistory',
        'Message', 'MessageReadStatus', 'GroupMembership',
        'Notification',
    ]

    # HTTP paths excluded from operations view
    NOISY_PATHS = [
        '/location/', '/tracking/',
        '/chat/messages/mark-read/',
        '/fcm-token/',
        '/notifications/read',
    ]

    def get_queryset(self):
        qs = AuditLog.objects.all()
        resource_type = self.request.query_params.get('resource_type')

        if resource_type == 'notification_error':
            # Error log tab — only show critical crashes, exclude trivial errors
            # like "permission_denied", "messaging/registration-token-not-registered"
            trivial_patterns = [
                'permission', 'not-registered', 'token-not-registered',
                'PERMISSION_DENIED', 'messaging/invalid-argument',
            ]
            qs = qs.filter(resource_type='notification_error')
            for pattern in trivial_patterns:
                qs = qs.exclude(changes__message__icontains=pattern)
                qs = qs.exclude(payload__message__icontains=pattern)
            return qs
        else:
            # Operations tab — exclude noisy resource types and paths
            qs = qs.exclude(resource_type__in=self.NOISY_RESOURCE_TYPES)
            qs = qs.exclude(resource_type='notification_error')
            for path_part in self.NOISY_PATHS:
                qs = qs.exclude(path__icontains=path_part)
            return qs

    @action(detail=False, methods=['post'], url_path='notification-errors')
    def notification_errors(self, request):
        """Store mobile/web notification error diagnostics in audit logs."""
        payload = request.data if isinstance(request.data, dict) else {'raw': request.data}
        error_message = (payload.get('message') or payload.get('error') or 'Notification error')[:255]

        log = AuditLog.objects.create(
            user=request.user if request.user.is_authenticated else None,
            action='ERROR',
            method='POST',
            path='/mobile/notifications',
            ip_address=request.META.get('REMOTE_ADDR'),
            resource_type='notification_error',
            resource_id=(payload.get('platform') or 'unknown'),
            payload=payload,
            changes={
                'source': payload.get('source'),
                'message': error_message,
                'code': payload.get('code'),
            },
        )
        return Response({'status': 'ok', 'id': log.id}, status=status.HTTP_201_CREATED)
