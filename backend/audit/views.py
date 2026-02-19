from rest_framework import serializers, viewsets, filters, permissions
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
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = AuditLogPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = {
        'created_at': ['date', 'gte', 'lte'],
        'method': ['exact'],
        'action': ['exact'],
        'user': ['exact'],
    }
    search_fields = ['path', 'payload', 'user__first_name', 'user__last_name', 'user__email']
    ordering_fields = ['created_at']
    ordering = ['-created_at']
