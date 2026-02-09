from django.db import models, transaction
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


class TaskViewSet(viewsets.ModelViewSet):
    """ViewSet for Task CRUD operations."""
    queryset = Task.objects.all()
    serializer_class = TaskSerializer
    pagination_class = TaskPagination
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Task.objects.select_related(
            'customer', 'assigned_to', 'group', 'group__region'
        ).prefetch_related(
            'task_services', 'task_services__service', 'task_services__values',
            'task_products', 'task_products__product', 'task_products__warehouse',
            'task_documents'
        ).order_by('created_at')
        
        # Filter by status
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
        
        # Filter by assigned_to
        assigned_to = self.request.query_params.get('assigned_to')
        if assigned_to:
            queryset = queryset.filter(assigned_to_id=assigned_to)
        
        # Filter by is_active
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
        
        return queryset
    
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
        """Soft delete - set is_active to False."""
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
            
            # Auto-assign if status changes to IN_PROGRESS and no assignee
            if new_status == Task.Status.IN_PROGRESS and not task.assigned_to:
                task.assigned_to = request.user
            
            # DONE olduqda task_products-ları anbardan çıxar
            if new_status == Task.Status.DONE:
                self._deduct_task_products(task, request.user)
                
            task.save()
            return Response(TaskSerializer(task).data)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
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
