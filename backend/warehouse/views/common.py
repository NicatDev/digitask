from rest_framework import viewsets, filters
from rest_framework.pagination import PageNumberPagination
from django_filters.rest_framework import DjangoFilterBackend
from ..models import Warehouse, Product
from ..serializers import WarehouseSerializer, ProductSerializer
from django.db import models
from django.db.models import Sum
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
    search_fields = ['name', 'brand', 'model', 'serial_number']
    filterset_fields = ['is_active', 'brand']

    def get_queryset(self):
        return Product.objects.annotate(
            total_stock=Coalesce(Sum('inventory_items__quantity'), 0, output_field=models.DecimalField())
        ).order_by('-id')
