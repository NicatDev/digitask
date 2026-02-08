from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.decorators import action
from rest_framework.pagination import PageNumberPagination
from django.utils import timezone
from ..models import TaskDocument
from ..serializers import TaskDocumentSerializer


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
        
        # Search by title
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(title__icontains=search)
        
        return queryset
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """Sənədi arxivə keçir - confirmed=True, shelf seçilir"""
        document = self.get_object()
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
        stock_movement = serializer.validated_data.get('stock_movement')
        action_text = serializer.validated_data.get('action')
        task = serializer.validated_data.get('task')
        
        # If stock_movement is provided and no action, generate action text
        if stock_movement and not action_text:
            action_text = f"{stock_movement.warehouse.name} - {stock_movement.get_movement_type_display()}"
            serializer.save(action=action_text)
        # If task is provided and no action, generate action text
        elif task and not action_text:
            action_text = f"Tapşırıq: {task.title}"
            serializer.save(action=action_text)
        else:
            serializer.save()
