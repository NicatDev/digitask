from rest_framework import viewsets, views, response, permissions
from django.utils import timezone
from .models import Event
from .serializers import EventSerializer
from tasks.models import Task, TaskType, Notification
from warehouse.models import StockMovement
from django.db.models import Count, Q
from datetime import timedelta

class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.all().order_by('-date')
    serializer_class = EventSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        # Clean up very old events option or filter by active
        active_only = self.request.query_params.get('active_only')
        if active_only == 'true':
            # Show events that are active and date is >= today (including passed hours today)
            now = timezone.now()
            qs = qs.filter(is_active=True, date__date__gte=now.date())
        return qs

    def perform_create(self, serializer):
        event = serializer.save()
        Notification.objects.create(
            title=f"Yeni Tədbir: {event.title}",
            message=event.description or "",
            notification_type=Notification.NotificationType.GENERAL
        )

class DashboardStatsView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # 1. Task Stats
        total_tasks = Task.objects.count()
        active_tasks = Task.objects.filter(is_active=True).count()
        
        # By Status
        status_stats = Task.objects.values('status').annotate(count=Count('id'))
        
        # By Type
        type_stats = Task.objects.values('task_type__name', 'task_type__color').annotate(count=Count('id'))

        # By User (Top 5) - All Time
        user_stats = Task.objects.exclude(assigned_to=None).values(
            'assigned_to__username', 
            'assigned_to__first_name', 
            'assigned_to__last_name',
            'assigned_to__group__name'
        ).annotate(
            total_tasks=Count('id'),
            active_tasks=Count('id', filter=Q(status__in=['todo', 'in_progress', 'arrived'])),
            done_tasks=Count('id', filter=Q(status='done'))
        ).order_by('-total_tasks')[:5]

        # 2. Warehouse Stats (Last 30 days)
        last_30_days = timezone.now() - timedelta(days=30)
        movements = StockMovement.objects.filter(created_at__gte=last_30_days)
        
        # Group by date and type
        # SQLite datetime truncation can be tricky in Django, keeping it simple for now or using strict day grouping if DB supports
        # For simple chart: Input vs Output counts
        movement_stats = movements.values('movement_type').annotate(count=Count('id'))

        return response.Response({
            'tasks': {
                'total': total_tasks,
                'active': active_tasks,
                'by_status': status_stats,
                'by_type': type_stats,
                'by_user': user_stats
            },
            'warehouse': {
                'movements_last_30_days': movement_stats
            }
        })
