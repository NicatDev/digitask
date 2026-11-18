from rest_framework import views, response, permissions
from django.db.models import Count, Q, F
from django.utils import timezone
from django.contrib.auth import get_user_model
from tasks.models import Task
from dateutil.relativedelta import relativedelta
import datetime

User = get_user_model()

# Azərbaycan vaxtı (UTC+4, yay saatı yoxdur). Gün/həftə/ay sərhədləri bu saatla hesablanır,
# server TIME_ZONE='UTC' olsa da "bu gün" istifadəçi üçün düzgün olsun deyə.
REPORT_TZ = datetime.timezone(datetime.timedelta(hours=4))
PERIODS = ('day', 'week', 'month')


def _parse_date(value):
    try:
        return datetime.date.fromisoformat(str(value)[:10])
    except (TypeError, ValueError):
        return None


def resolve_period_range(params):
    """
    Query parametrlərindən [start, end) aralığı qaytarır (aware datetime).

    Yeni format:  ?period=day|week|month&date=YYYY-MM-DD  (date yoxdursa: bu gün)
    Köhnə format: ?month=&year=  (period göndərilməyəndə) — köhnə mobil versiyalar üçün.
    Həftə bazar ertəsindən başlayır.
    """
    today = timezone.now().astimezone(REPORT_TZ).date()
    period = params.get('period')

    if period not in PERIODS:
        # Geriyə uyğunluq: ay/il
        period = 'month'
        try:
            anchor = datetime.date(
                int(params.get('year', today.year)),
                int(params.get('month', today.month)),
                1,
            )
        except (TypeError, ValueError):
            anchor = today
    else:
        anchor = _parse_date(params.get('date')) or today

    if period == 'day':
        start_d = anchor
        end_d = anchor + datetime.timedelta(days=1)
    elif period == 'week':
        start_d = anchor - datetime.timedelta(days=anchor.weekday())
        end_d = start_d + datetime.timedelta(days=7)
    else:
        start_d = anchor.replace(day=1)
        end_d = start_d + relativedelta(months=1)

    to_dt = lambda d: datetime.datetime.combine(d, datetime.time.min, tzinfo=REPORT_TZ)
    return period, to_dt(start_d), to_dt(end_d)


class UserPerformanceView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        _period, range_start, range_end = resolve_period_range(request.query_params)
        
        # 1. Get ALL active users (employees)
        users = User.objects.filter(is_active=True).order_by('username')

        results = []
        
        for user in users:
            # Revised Logic requested by User:
            # "Total" = Active + Completed. This represents the "Total Volume" relevant to this month/snapshot.
            
            # Metric 1: Tasks Completed (Status DONE and updated_at in selected day/week/month)
            completed_tasks = Task.objects.filter(
                assigned_to=user,
                status='done',
                updated_at__gte=range_start,
                updated_at__lt=range_end,
            )
            
            # Metric 2: Active Tasks (Current snapshot)
            active_tasks = Task.objects.filter(
                assigned_to=user,
                status__in=['todo', 'in_progress']
            )

            completed_count = completed_tasks.count()
            active_count = active_tasks.count()
            # Seçilmiş dövr ərzində yaradılmış və hazırda hələ aktiv olan tapşırıqlar
            active_in_period_count = active_tasks.filter(
                created_at__gte=range_start,
                created_at__lt=range_end,
            ).count()
            
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
                    'active_in_period': active_in_period_count,
                    'efficiency': efficiency
                },
                'breakdown': {
                    'types': list(types),
                    'services': list(services)
                }
            })
            
        return response.Response(results)
