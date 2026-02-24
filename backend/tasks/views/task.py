from django.db import models, transaction
from django.contrib.auth import get_user_model
from rest_framework import viewsets, status
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from decimal import Decimal
from ..models import Task, TaskService, TaskProduct
from ..serializers import TaskSerializer, TaskServiceSerializer, TaskStatusUpdateSerializer, TaskProductSerializer, TaskProductCreateSerializer
from warehouse.models import WarehouseInventory, StockMovement
from ..pagination import TaskPagination

User = get_user_model()


class TaskViewSet(viewsets.ModelViewSet):
    """ViewSet for Task CRUD operations."""
    queryset = Task.objects.all()
    serializer_class = TaskSerializer
    pagination_class = TaskPagination
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Task.objects.select_related(
            'customer', 'group', 'group__region'
        ).prefetch_related(
            'assigned_to',
            'task_services', 'task_services__service', 'task_services__values',
            'task_products', 'task_products__product', 'task_products__warehouse',
            'task_documents'
        ).order_by('-created_at')
        
        user = self.request.user
        
        # Visibility rules — privileged users see everything
        role = getattr(user, 'role', None)
        is_privileged = (
            (role and role.is_task_writer) or
            (role and role.is_admin) or
            (role and role.is_super_admin) or
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
        
        # Search - title, customer name, register_number, note
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                models.Q(title__icontains=search) |
                models.Q(customer__full_name__icontains=search) |
                models.Q(customer__register_number__icontains=search) |
                models.Q(note__icontains=search)
            )
        
        return queryset.distinct()
    
    def perform_create(self, serializer):
        """Create task and trigger notification."""
        task = serializer.save()
        
        # Create notification
        from notifications.services import send_notification
        send_notification(
            title=f"Yeni Task: {task.title}",
            message=f"Müştəri: {task.customer.full_name if task.customer else 'N/A'}",
            notification_type='task_created',
            related_task=task
        )
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False. Only privileged users can delete."""
        role = getattr(request.user, 'role', None)
        is_privileged = (
            (role and role.is_task_writer) or
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
    
    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        """Update task status."""
        task = self.get_object()
        serializer = TaskStatusUpdateSerializer(data=request.data)
        
        if serializer.is_valid():
            new_status = serializer.validated_data['status']
            task.status = new_status
            
            # Auto-assign if status changes to IN_PROGRESS and no assignees
            if new_status == Task.Status.IN_PROGRESS and not task.assigned_to.exists():
                task.save()
                task.assigned_to.add(request.user)
            else:
                task.save()
            
            # DONE olduqda task_products-ları anbardan çıxar
            if new_status == Task.Status.DONE:
                self._deduct_task_products(task, request.user)
                
                # Send task completion notification
                from notifications.models import Notification
                notification = Notification.objects.create(
                    title="Tapşırıq tamamlandı",
                    message=f"{task.title} tapşırığı tamamlandı.",
                    notification_type=Notification.NotificationType.TASK_COMPLETED,
                    related_task=task
                )
                # Target all assignees
                assignees = task.assigned_to.all()
                if assignees.exists():
                    notification.target_users.set(assignees)
                
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
        return Response(TaskSerializer(task).data)
    
    @action(detail=True, methods=['post'])
    def join_task(self, request, pk=None):
        """Allow current user to join the task as an assignee."""
        task = self.get_object()
        task.assigned_to.add(request.user)
        return Response(TaskSerializer(task).data)
    
    def _deduct_task_products(self, task, user):
        """Tapşırıq tamamlandıqda məhsulları anbardan çıxar."""
        task_products = task.task_products.filter(is_deducted=False)
        
        with transaction.atomic():
            for tp in task_products:
                inventory, created = WarehouseInventory.objects.get_or_create(
                    warehouse=tp.warehouse,
                    product=tp.product
                )
                
                qty_old = inventory.quantity
                qty_new = qty_old - tp.quantity
                
                inventory.quantity = qty_new
                inventory.save()
                
                # Stock movement yarat
                StockMovement.objects.create(
                    warehouse=tp.warehouse,
                    product=tp.product,
                    movement_type=StockMovement.Type.OUT,
                    reason=f"Tapşırıq #{task.id} icrası zamanı istifadə olunmuşdur",
                    quantity_old=qty_old,
                    quantity_new=qty_new,
                    created_by=user,
                    reference_no=f"TASK-{task.id}"
                )
                
                # İşarələ ki, artıq çıxarılıb
                tp.is_deducted = True
                tp.save()


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
