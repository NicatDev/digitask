from rest_framework import viewsets, filters
from rest_framework.pagination import PageNumberPagination
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import status as drf_status
from django_filters.rest_framework import DjangoFilterBackend
from ..models import Warehouse, Product, ProductCategory, CategoryField
from ..serializers import (
    WarehouseSerializer, ProductSerializer,
    ProductCategorySerializer, CategoryFieldSerializer
)
from django.db import models
from django.db.models import Sum, Count, Q
from django.db.models.functions import Coalesce


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 5
    page_size_query_param = 'page_size'
    max_page_size = 100


class BaseSoftDeleteViewSet(viewsets.ModelViewSet):
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    
    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()


class WarehouseViewSet(BaseSoftDeleteViewSet):
    queryset = Warehouse.objects.all()
    serializer_class = WarehouseSerializer
    search_fields = ['name', 'address', 'note']
    filterset_fields = ['is_active', 'region']

    def get_queryset(self):
        return super().get_queryset()


class ProductViewSet(BaseSoftDeleteViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    search_fields = ['name', 'brand', 'model', 'serial_items__serial_number']
    filterset_fields = ['is_active', 'brand', 'category', 'has_serial_number']

    def get_queryset(self):
        qs = Product.objects.annotate(
            total_stock=Coalesce(Sum('inventory_items__quantity'), 0, output_field=models.DecimalField()),
            serial_count=Count('serial_items')
        ).order_by('-id')
        
        # Default: show only active products unless explicitly filtered
        if 'is_active' not in self.request.query_params:
            qs = qs.filter(is_active=True)
        
        return qs


class ProductCategoryViewSet(BaseSoftDeleteViewSet):
    queryset = ProductCategory.objects.all()
    serializer_class = ProductCategorySerializer
    search_fields = ['name']
    filterset_fields = ['is_active']

    @action(detail=True, methods=['post'], url_path='add-field')
    def add_field(self, request, pk=None):
        """Add a dynamic field to a category."""
        category = self.get_object()
        serializer = CategoryFieldSerializer(data={
            'category': category.id,
            'name': request.data.get('name'),
            'field_type': request.data.get('field_type', 'string'),
            'is_required': request.data.get('is_required', False),
        })
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=drf_status.HTTP_201_CREATED)
        return Response(serializer.errors, status=drf_status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['delete'], url_path='remove-field/(?P<field_id>[^/.]+)')
    def remove_field(self, request, pk=None, field_id=None):
        """Remove a dynamic field from a category."""
        category = self.get_object()
        try:
            field = CategoryField.objects.get(id=field_id, category=category)
            field.delete()
            return Response(status=drf_status.HTTP_204_NO_CONTENT)
        except CategoryField.DoesNotExist:
            return Response({'error': 'Field not found'}, status=drf_status.HTTP_404_NOT_FOUND)
