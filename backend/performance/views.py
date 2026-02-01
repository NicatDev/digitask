from rest_framework import views, response, permissions
from django.db.models import Count, Q, F
from django.utils import timezone
from django.contrib.auth import get_user_model
from tasks.models import Task
from dateutil.relativedelta import relativedelta
import datetime

User = get_user_model()

class UserPerformanceView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        now = timezone.now()
        month = int(request.query_params.get('month', now.month))
        year = int(request.query_params.get('year', now.year))
        
        # 1. Get ALL active users (employees)
        users = User.objects.filter(is_active=True).order_by('username')

        results = []
        
        for user in users:
            # Revised Logic requested by User:
            # "Total" = Active + Completed. This represents the "Total Volume" relevant to this month/snapshot.
            
            # Metric 1: Tasks Completed (Status DONE and updated_at in this month)
            completed_tasks = Task.objects.filter(
                assigned_to=user,
                status='done',
                updated_at__year=year,
                updated_at__month=month
            )
            
            # Metric 2: Active Tasks (Current snapshot)
            active_tasks = Task.objects.filter(
                assigned_to=user,
                status__in=['todo', 'in_progress', 'arrived']
            )

            completed_count = completed_tasks.count()
            active_count = active_tasks.count()
            
            # Total Volume = Completed (Efficiency) + Active (Backlog)
            # This ensures Total >= Completed and Total >= Active
            total_volume = completed_count + active_count
            
            # Breakdown: We need to show "What they did/are doing".
            # Combine IDs of both sets to get a unique list for breakdown
            relevant_task_ids = list(completed_tasks.values_list('id', flat=True)) + list(active_tasks.values_list('id', flat=True))
            relevant_tasks = Task.objects.filter(id__in=relevant_task_ids)

            # Type Breakdown
            types = relevant_tasks.values('task_type__name').annotate(count=Count('id')).order_by('-count')
            
            # Service Breakdown
            services = relevant_tasks.values('services__name').annotate(count=Count('id')).exclude(services__name=None).order_by('-count')

            efficiency = 0
            if total_volume > 0:
                efficiency = round((completed_count / total_volume * 100), 1)

            results.append({
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'full_name': user.get_full_name() or user.username,
                },
                'stats': {
                    'total': total_volume,
                    'completed': completed_count,
                    'active': active_count,
                    'efficiency': efficiency
                },
                'breakdown': {
                    'types': list(types),
                    'services': list(services)
                }
            })
            
        return response.Response(results)
