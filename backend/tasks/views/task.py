from django.db import models, transaction
from django.db.models import Case, IntegerField, Q, Value, When
from django.db.models.functions import Cast
from django.utils import timezone
from django.contrib.auth import get_user_model
from django.http import Http404
from django.shortcuts import get_object_or_404
from rest_framework import viewsets, status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from decimal import Decimal
from ..models import Task, TaskService, TaskProduct, TaskActivity, Customer
from ..serializers import (
    TaskSerializer,
    TaskServiceSerializer,
    TaskStatusUpdateSerializer,
    TaskProductSerializer,
    TaskProductCreateSerializer,
    TaskActivitySerializer,
    TaskCustomerHistorySerializer,
)
from ..services.task_activity import log_task_activity, task_status_label
from warehouse.models import WarehouseInventory, StockMovement
from ..pagination import TaskPagination
from notifications.models import Notification
from notifications.services import send_notification  # type: ignore
from notifications.task_helpers import (
    format_task_line,
    task_with_customer,
    user_ids_in_task_group,
    user_ids_privileged_in_task_group,
)

User = get_user_model()


class TaskViewSet(viewsets.ModelViewSet):
    """ViewSet for Task CRUD operations."""
    queryset = Task.objects.all()
    serializer_class = TaskSerializer
    pagination_class = TaskPagination
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Task.objects.select_related(
            'customer',
            'customer__equipment',
            'customer__optic_box',
            'group',
            'group__region',
            'reporter',
        ).prefetch_related(
            'assigned_to',
            'task_services', 'task_services__service', 'task_services__values',
            'task_products', 'task_products__product', 'task_products__warehouse',
            'task_documents'
        )
        
        user = self.request.user
        
        # Visibility rules — admin / super_admin / Django superuser hamısını görür.
        # Bundan əlavə: role.is_task_view_all seçiləndə (admin olmasa da) hamısını görür.
        role = getattr(user, 'role', None)
        is_privileged = (
            (role and role.is_admin) or
            (role and role.is_super_admin) or
            (role and getattr(role, 'is_task_view_all', False)) or
            user.is_superuser
        )
        
        if not is_privileged:
            # Regular users see:
            # 1) All TODO tasks (unaccepted, visible to everyone)
            # 2) Tasks where they are in assigned_to
            # But ALWAYS exclude done/rejected tasks where they are assigned
            queryset = queryset.filter(
                models.Q(status='todo') |  # all TODO tasks
                models.Q(assigned_to=user)  # tasks assigned to me
            ).exclude(
                assigned_to=user,
                status__in=['done', 'rejected']
            )
        
        # Filter by status (query param)
        task_status = self.request.query_params.get('status')
        if task_status:
            queryset = queryset.filter(status=task_status)
        
        # Filter by customer
        customer = self.request.query_params.get('customer')
        if customer:
            queryset = queryset.filter(customer_id=customer)
        
        # Filter by group
        group = self.request.query_params.get('group')
        if group:
            queryset = queryset.filter(group_id=group)
        
        # Filter by assigned_to (M2M) — query param
        assigned_to = self.request.query_params.get('assigned_to')
        if assigned_to:
            queryset = queryset.filter(assigned_to__id=assigned_to)
        
        # Filter by is_active (default: active only)
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Filter by date range
        date_from = self.request.query_params.get('date_from')
        if date_from:
            queryset = queryset.filter(created_at__date__gte=date_from)
        
        date_to = self.request.query_params.get('date_to')
        if date_to:
            queryset = queryset.filter(created_at__date__lte=date_to)
        
        # Ümumi axtarış — başlıq, müştəri, qeydiyyat, qeyd, ID mətni
        search = (self.request.query_params.get('search') or '').strip()
        id_search = (self.request.query_params.get('id_search') or '').strip()
        register_number_search = (self.request.query_params.get('register_number_search') or '').strip()

        # ID sütunu: yalnız rəqəmsə dəqiq pk, əks halda mətn üzrə icontains
        id_search_non_digit = bool(id_search) and not id_search.isdigit()
        if search or id_search_non_digit:
            queryset = queryset.annotate(str_id=Cast('id', output_field=models.TextField()))

        if search:
            queryset = queryset.filter(
                models.Q(str_id__icontains=search) |
                models.Q(title__icontains=search) |
                models.Q(customer__full_name__icontains=search) |
                models.Q(customer__register_number__icontains=search) |
                models.Q(note__icontains=search)
            )

        if id_search:
            if id_search.isdigit():
                queryset = queryset.filter(id=int(id_search))
            else:
                queryset = queryset.filter(str_id__icontains=id_search)

        if register_number_search:
            queryset = queryset.filter(customer__register_number__icontains=register_number_search)

        queryset = queryset.distinct()

        # Cədvəl sırası: ordering verilərsə həmin sütun (whitelist), yoxsa status ardıcıllığı
        ordering = (self.request.query_params.get('ordering') or '').strip()
        ordering_whitelist = {
            'id': ('id', '-created_at'),
            '-id': ('-id', '-created_at'),
            'register_number': ('customer__register_number', 'id', '-created_at'),
            '-register_number': ('-customer__register_number', 'id', '-created_at'),
        }

        if ordering in ordering_whitelist:
            queryset = queryset.order_by(*ordering_whitelist[ordering])
        else:
            today = timezone.now().date()
            queryset = queryset.annotate(
                _overdue_pending=Case(
                    When(
                        Q(status=Task.Status.PENDING)
                        & Q(rescheduled_date__isnull=False)
                        & Q(rescheduled_date__lte=today),
                        then=Value(0),
                    ),
                    default=Value(1),
                    output_field=IntegerField(),
                ),
                _status_order=Case(
                    When(status__in=['in_progress', 'arrived'], then=Value(0)),
                    When(status=Task.Status.TODO, then=Value(1)),
                    When(status=Task.Status.PENDING, then=Value(2)),
                    When(status=Task.Status.DONE, then=Value(3)),
                    When(status=Task.Status.REJECTED, then=Value(4)),
                    default=Value(99),
                    output_field=IntegerField(),
                ),
            ).order_by('_overdue_pending', '_status_order', 'rescheduled_date', '-created_at')

        # Annotasiyada assigned_to (M2M) join-u eyni Task üçün bir neçə sətir yarada bilər;
        # əks halda .get(pk=...) → MultipleObjectsReturned (məs. /tasks/116/activity/).
        return queryset.distinct()

    def get_object(self):
        """filter_queryset + M2M annotasiya səbəbindən təkrarlanan sətirlərdə .get() əvəzinə."""
        queryset = self.filter_queryset(self.get_queryset())
        lookup_url_kwarg = self.lookup_url_kwarg or self.lookup_field
        assert lookup_url_kwarg in self.kwargs, (
            f'Expected URL keyword argument "{lookup_url_kwarg}".'
        )
        filter_kwargs = {self.lookup_field: self.kwargs[lookup_url_kwarg]}
        obj = queryset.filter(**filter_kwargs).first()
        if obj is None:
            raise Http404
        self.check_object_permissions(self.request, obj)
        return obj

    def perform_create(self, serializer):
        """Create task and notify users in the task's group only (not all users)."""
        task = serializer.save(reporter=self.request.user)
        log_task_activity(
            task,
            self.request.user,
            TaskActivity.Action.TASK_CREATED,
            message=task.title,
        )

        task = task_with_customer(task)
        if not task.group_id:
            return

        recipient_ids = user_ids_in_task_group(task)
        if not recipient_ids:
            return

        line = format_task_line(task)
        send_notification(
            title=f"Yeni tapşırıq: {task.title}",
            message=f"{line}\nMüştəri: {task.customer.full_name if task.customer else '—'}",
            notification_type=Notification.NotificationType.TASK_CREATED,
            related_task=task,
            target_user_ids=recipient_ids,
            dedupe_seconds=30,
        )

    def perform_update(self, serializer):
        instance = serializer.instance
        old_title = instance.title
        old_note = instance.note
        task = serializer.save()
        changed = []
        if task.title != old_title:
            changed.append('başlıq')
        if task.note != old_note:
            changed.append('qeyd')
        if changed:
            log_task_activity(
                task,
                self.request.user,
                TaskActivity.Action.TASK_UPDATED,
                message=', '.join(changed) + ' yeniləndi',
            )
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False. Only privileged users can delete."""
        role = getattr(request.user, 'role', None)
        is_privileged = (
            (role and role.is_admin) or
            (role and role.is_super_admin) or
            request.user.is_superuser
        )
        if not is_privileged:
            return Response(
                {'error': 'You do not have permission to delete tasks.'},
                status=status.HTTP_403_FORBIDDEN
            )
        instance = self.get_object()
        instance.is_active = False
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    @action(detail=True, methods=['get', 'post'])
    def activity(self, request, pk=None):
        """GET: timeline; POST: { body } comment."""
        task = self.get_object()
        if request.method == 'GET':
            qs = TaskActivity.objects.filter(task=task).select_related('user').order_by('-created_at')
            return Response(TaskActivitySerializer(qs, many=True).data)
        body = (request.data.get('body') or '').strip()
        if not body:
            return Response({'error': 'body is required'}, status=status.HTTP_400_BAD_REQUEST)
        act = log_task_activity(
            task,
            request.user,
            TaskActivity.Action.COMMENT,
            message=body,
        )
        return Response(TaskActivitySerializer(act).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'])
    def customer_tasks(self, request, pk=None):
        """Same müştərinin bütün tapşırıqları (icazə qaydaları ilə), köhnədən yeniyə."""
        task = self.get_object()
        qs = (
            self.get_queryset()
            .filter(customer_id=task.customer_id)
            .order_by('_overdue_pending', '_status_order', 'rescheduled_date', '-created_at')
            .prefetch_related('assigned_to')
        )
        return Response(TaskCustomerHistorySerializer(qs, many=True).data)

    @action(detail=False, methods=['get'], url_path='by-customer')
    def by_customer(self, request):
        """Müştəri ID-si ilə tapşırıq tarixçəsi — eyni icazə qaydaları; performans üçün ayrıca çağırış."""
        customer_id = request.query_params.get('customer')
        if not customer_id:
            return Response(
                {'error': 'customer query parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        get_object_or_404(Customer, pk=customer_id)
        qs = (
            self.get_queryset()
            .filter(customer_id=customer_id)
            .order_by('_overdue_pending', '_status_order', 'rescheduled_date', '-created_at')
            .prefetch_related('assigned_to')
        )
        return Response(TaskCustomerHistorySerializer(qs, many=True).data)

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """Update task status."""
        task = self.get_object()
        old_status = task.status
        serializer = TaskStatusUpdateSerializer(data=request.data)
        
        if serializer.is_valid():
            new_status = serializer.validated_data['status']
            rd = serializer.validated_data.get('rescheduled_date')
            reject_note = serializer.validated_data.get('reject_note')
            task.status = new_status
            if new_status == Task.Status.PENDING:
                task.rescheduled_date = rd
            else:
                task.rescheduled_date = None

            # Auto-assign if status changes to IN_PROGRESS and no assignees
            if new_status == Task.Status.IN_PROGRESS and not task.assigned_to.exists():
                task.save()
                task.assigned_to.add(request.user)
            else:
                task.save()

            log_meta = {'from': old_status, 'to': new_status}
            if task.rescheduled_date:
                log_meta['rescheduled_date'] = str(task.rescheduled_date)
            if reject_note:
                log_meta['reject_note'] = reject_note
            status_msg = (
                f"{task_status_label(old_status)} → {task_status_label(new_status)}"
                + (f" (tarix: {task.rescheduled_date})" if task.rescheduled_date else '')
            )
            if reject_note:
                status_msg = f"{status_msg}\nQeyd: {reject_note}"
            log_task_activity(
                task,
                request.user,
                TaskActivity.Action.STATUS_CHANGE,
                message=status_msg,
                meta=log_meta,
            )

            task = task_with_customer(task)
            line = format_task_line(task)

            if old_status != new_status:
                if new_status == Task.Status.DONE:
                    self._deduct_task_products(task, request.user)
                    done_ids = user_ids_in_task_group(task)
                    if done_ids:
                        send_notification(
                            title="Tapşırıq tamamlandı",
                            message=f"{line}\n{task.title}",
                            notification_type=Notification.NotificationType.TASK_COMPLETED,
                            related_task=task,
                            target_user_ids=done_ids,
                            dedupe_seconds=60,
                        )
                else:
                    priv = user_ids_privileged_in_task_group(task)
                    if priv:
                        send_notification(
                            title="Tapşırıq statusu dəyişdi",
                            message=f"{line}\n{task_status_label(old_status)} → {task_status_label(new_status)}",
                            notification_type=Notification.NotificationType.TASK_STATUS_CHANGED,
                            related_task=task,
                            target_user_ids=priv,
                            dedupe_seconds=45,
                        )

            return Response(TaskSerializer(task).data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=True, methods=['post'])
    def add_assignee(self, request, pk=None):
        """Add a user to the task's assignees. Only existing assignees can add others."""
        task = self.get_object()
        user_id = request.data.get('user_id')
        
        if not user_id:
            return Response({'error': 'user_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if request user is already an assignee
        if not task.assigned_to.filter(id=request.user.id).exists():
            return Response({'error': 'Only existing assignees can add others'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        
        task.assigned_to.add(user)
        log_task_activity(
            task,
            request.user,
            TaskActivity.Action.ASSIGNEE_ADDED,
            message=f"{user.get_full_name() or user.username} əlavə edildi",
            meta={'added_user_id': user.id},
        )
        return Response(TaskSerializer(task).data)
    
    @action(detail=True, methods=['post'])
    def join_task(self, request, pk=None):
        """Allow current user to join the task as an assignee."""
        task = self.get_object()
        task.assigned_to.add(request.user)
        log_task_activity(
            task,
            request.user,
            TaskActivity.Action.ASSIGNEE_ADDED,
            message=f"{request.user.get_full_name() or request.user.username} icraya qoşuldu",
            meta={'self_join': True},
        )
        return Response(TaskSerializer(task).data)
    
    def _deduct_task_products(self, task, user):
        """Tapşırıq tamamlandıqda məhsulları anbardan çıxar."""
        from warehouse.models import SerialNumberItem
        
        task_products = task.task_products.select_related('product', 'warehouse').filter(is_deducted=False)
        
        for tp in task_products:
            try:
                with transaction.atomic():
                    inventory, created = WarehouseInventory.objects.get_or_create(
                        warehouse=tp.warehouse,
                        product=tp.product
                    )
                    
                    qty_old = inventory.quantity

                    if tp.product.has_serial_number and tp.serial_number:
                        # Serial product: delete serial item from warehouse
                        deleted_count, _ = SerialNumberItem.objects.filter(
                            serial_number=tp.serial_number,
                            product=tp.product,
                            warehouse=tp.warehouse
                        ).delete()
                        qty_new = qty_old - 1
                    elif tp.product.has_serial_number:
                        # Serial product but no serial_number recorded - still deduct 1
                        qty_new = qty_old - 1
                    else:
                        # Normal product: deduct quantity
                        qty_new = qty_old - tp.quantity
                    
                    inventory.quantity = qty_new
                    inventory.save()
                    
                    # Stock movement yarat
                    sm = StockMovement.objects.create(
                        warehouse=tp.warehouse,
                        product=tp.product,
                        movement_type=StockMovement.Type.OUT,
                        reason=f"Tapşırıq #{task.id} icrası zamanı istifadə olunmuşdur",
                        quantity_old=qty_old,
                        quantity_new=qty_new,
                        created_by=user,
                        reference_no=f"TASK-{task.id}",
                        serial_number=tp.serial_number or ''
                    )
                    
                    tp.is_deducted = True
                    tp.save()
            except Exception as e:
                import traceback
                traceback.print_exc()


class TaskServiceViewSet(viewsets.ModelViewSet):
    """ViewSet for TaskService operations."""
    queryset = TaskService.objects.all()
    serializer_class = TaskServiceSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    
    def get_queryset(self):
        queryset = TaskService.objects.select_related(
            'task', 'service'
        ).prefetch_related('values', 'values__column')
        
        # Filter by task
        task = self.request.query_params.get('task')
        if task:
            queryset = queryset.filter(task_id=task)
        
        return queryset

    def perform_create(self, serializer):
        ts = serializer.save()
        log_task_activity(
            ts.task,
            self.request.user,
            TaskActivity.Action.SURVEY_SAVED,
            message=f"Anket: {ts.service.name}",
            meta={'task_service_id': ts.id, 'service_id': ts.service_id},
        )
        task = task_with_customer(ts.task)
        ids = user_ids_privileged_in_task_group(task)
        if ids:
            line = format_task_line(task)
            send_notification(
                title=f"Anket dolduruldu: {ts.service.name}",
                message=f"{line}\n{task.title}",
                notification_type=Notification.NotificationType.SURVEY_SAVED,
                related_task=task,
                target_user_ids=ids,
                dedupe_seconds=90,
            )

    def perform_update(self, serializer):
        ts = serializer.save()
        log_task_activity(
            ts.task,
            self.request.user,
            TaskActivity.Action.SURVEY_SAVED,
            message=f"Anket yeniləndi: {ts.service.name}",
            meta={'task_service_id': ts.id},
        )
        task = task_with_customer(ts.task)
        ids = user_ids_privileged_in_task_group(task)
        if ids:
            line = format_task_line(task)
            send_notification(
                title=f"Anket yeniləndi: {ts.service.name}",
                message=f"{line}\n{task.title}",
                notification_type=Notification.NotificationType.SURVEY_SAVED,
                related_task=task,
                target_user_ids=ids,
                dedupe_seconds=90,
            )
