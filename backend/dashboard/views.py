from rest_framework import viewsets, views, response, permissions
from django.utils import timezone
from .models import Event
from .serializers import EventSerializer
from tasks.models import Task, TaskType
from notifications.models import Notification
from notifications.services import send_notification
from warehouse.models import StockMovement
from performance.views import resolve_period_range, completed_in_range, active_tasks_qs
from django.db.models import Count, Q
from datetime import timedelta

class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.all().order_by('-created_at')
    serializer_class = EventSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset().prefetch_related('event_images')
        active_only = self.request.query_params.get('active_only')
        if active_only == 'true':
            now = timezone.now()
            qs = qs.filter(is_active=True, date__date__gte=now.date()).order_by('-created_at')
        return qs

    def perform_create(self, serializer):
        event = serializer.save()
        send_notification(
            title=f"Yeni tədbir: {event.title}",
            message=event.description or "",
            notification_type=Notification.NotificationType.EVENT_CREATED,
            related_task=None,
            target_user_ids=None,
            dedupe_seconds=30,
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

        # By User (Top 5). period=month -> ayın 1-dən indiyə qədər həqiqətən
        # tamamlanmış (TaskActivity "→ done") + hazırda açıq tapşırıqlar.
        user_tasks = Task.objects.filter(assigned_to__isnull=False, is_active=True)
        order_by = ('-total_tasks',)
        if request.query_params.get('period') == 'month':
            _p, month_start, _end = resolve_period_range({'period': 'month'})
            done_ids = completed_in_range(month_start, timezone.now()).values('id')
            active_ids = active_tasks_qs().values('id')
            user_tasks = user_tasks.filter(Q(id__in=done_ids) | Q(id__in=active_ids))
            order_by = ('-done_tasks', '-total_tasks')
        user_stats = user_tasks.values(
            'assigned_to__username', 
            'assigned_to__first_name', 
            'assigned_to__last_name',
            'assigned_to__group__name',
            'assigned_to__avatar'
        ).annotate(
            total_tasks=Count('id'),
            active_tasks=Count('id', filter=Q(status__in=['todo', 'in_progress'])),
            done_tasks=Count('id', filter=Q(status='done'))
        ).order_by(*order_by)[:5]

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
