from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from ..models import TaskProduct
from ..serializers import TaskProductSerializer, TaskProductCreateSerializer
from warehouse.models import Product, Warehouse


class TaskProductViewSet(viewsets.ModelViewSet):
    """ViewSet for TaskProduct CRUD operations."""
    queryset = TaskProduct.objects.all()
    serializer_class = TaskProductSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = TaskProduct.objects.select_related(
            'task', 'product', 'warehouse'
        ).order_by('-created_at')
        
        # Filter by task
        task = self.request.query_params.get('task')
        if task:
            queryset = queryset.filter(task_id=task)
        
        return queryset
    
    @action(detail=False, methods=['post'], url_path='bulk-create')
    def bulk_create(self, request):
        """Toplu TaskProduct yaratmaq."""
        serializer = TaskProductCreateSerializer(data=request.data)
        
        if serializer.is_valid():
            task_id = request.data.get('task_id')
            products_data = serializer.validated_data['products']
            
            if not task_id:
                return Response({'error': 'task_id required'}, status=status.HTTP_400_BAD_REQUEST)
            
            created_products = []
            for item in products_data:
                product_id = item.get('product_id')
                warehouse_id = item.get('warehouse_id')
                quantity = item.get('quantity')
                
                if not all([product_id, warehouse_id, quantity]):
                    continue
                
                try:
                    product = Product.objects.get(id=product_id)
                    warehouse = Warehouse.objects.get(id=warehouse_id)
                    
                    tp = TaskProduct.objects.create(
                        task_id=task_id,
                        product=product,
                        warehouse=warehouse,
                        quantity=quantity
                    )
                    created_products.append(TaskProductSerializer(tp).data)
                except (Product.DoesNotExist, Warehouse.DoesNotExist):
                    continue
            
            return Response({'created': created_products}, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
