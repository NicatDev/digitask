from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import PermissionDenied
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from django.utils import timezone
from ..models import TaskDocument
from ..serializers import TaskDocumentSerializer
from users.task_permissions import can_task_action_for_task


class DocumentPagination(PageNumberPagination):
    page_size = 5
    page_size_query_param = 'page_size'
    max_page_size = 100


class TaskDocumentViewSet(viewsets.ModelViewSet):
    """ViewSet for TaskDocument CRUD operations."""
    queryset = TaskDocument.objects.all()
    serializer_class = TaskDocumentSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    pagination_class = DocumentPagination
    
    def get_queryset(self):
        queryset = TaskDocument.objects.select_related(
            'task', 'stock_movement', 'shelf', 'confirmed_by'
        ).order_by('-created_at')
        
        task = self.request.query_params.get('task')
        if task:
            queryset = queryset.filter(task_id=task)
        
        # Filter by stock_movement
        stock_movement = self.request.query_params.get('stock_movement')
        if stock_movement:
            queryset = queryset.filter(stock_movement_id=stock_movement)
        
        # Filter by confirmed status
        confirmed = self.request.query_params.get('confirmed')
        if confirmed is not None:
            queryset = queryset.filter(confirmed=confirmed.lower() == 'true')
        
        # Filter by shelf
        shelf = self.request.query_params.get('shelf')
        if shelf:
            queryset = queryset.filter(shelf_id=shelf)
        
        # Filter by is_active
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Search by title
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(title__icontains=search)
        
        return queryset
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False."""
        instance = self.get_object()
        if not can_task_action_for_task(request.user, 'manage_documents', instance.task):
            return Response({'error': 'You do not have permission to delete task documents.'}, status=status.HTTP_403_FORBIDDEN)
        instance.is_active = False
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """Sənədi arxivə keçir - confirmed=True, shelf seçilir"""
        document = self.get_object()
        if not can_task_action_for_task(request.user, 'manage_documents', document.task):
            return Response({'error': 'You do not have permission to archive task documents.'}, status=status.HTTP_403_FORBIDDEN)
        shelf_id = request.data.get('shelf')
        
        if not shelf_id:
            return Response(
                {'error': 'Rəf seçilməlidir'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        document.confirmed = True
        document.confirmed_by = request.user
        document.confirmed_at = timezone.now()
        document.shelf_id = shelf_id
        document.save()
        
        serializer = self.get_serializer(document)
        return Response(serializer.data)

    def perform_create(self, serializer):
        target_task = serializer.validated_data.get('task')
        if not can_task_action_for_task(self.request.user, 'manage_documents', target_task):
            raise PermissionDenied("Task document create permission denied")
        from tasks.models import TaskActivity
        from tasks.services.task_activity import log_task_activity

        stock_movement = serializer.validated_data.get('stock_movement')
        action_text = serializer.validated_data.get('action')
        task = serializer.validated_data.get('task')

        # If stock_movement is provided and no action, generate action text
        if stock_movement and not action_text:
            action_text = f"{stock_movement.warehouse.name} - {stock_movement.get_movement_type_display()}"
            instance = serializer.save(action=action_text)
        # If task is provided and no action, generate action text
        elif task and not action_text:
            action_text = f"Tapşırıq: {task.title}"
            instance = serializer.save(action=action_text)
        else:
            instance = serializer.save()

        if instance.task_id:
            log_task_activity(
                instance.task,
                self.request.user,
                TaskActivity.Action.DOCUMENT_ADDED,
                message=instance.title or action_text or 'Sənəd',
            )

    def perform_update(self, serializer):
        if not can_task_action_for_task(self.request.user, 'manage_documents', serializer.instance.task):
            raise PermissionDenied("Task document update permission denied")
        serializer.save()
