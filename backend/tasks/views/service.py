from rest_framework import viewsets, filters
from rest_framework.pagination import PageNumberPagination
from django_filters.rest_framework import DjangoFilterBackend
from ..models import Service, Column
from ..serializers import ServiceSerializer, ColumnSerializer


class StandardResultsSetPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100


class ServiceViewSet(viewsets.ModelViewSet):
    """CRUD for Services with soft delete support."""
    queryset = Service.objects.all()
    serializer_class = ServiceSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'id']
    ordering = ['name']


class ColumnViewSet(viewsets.ModelViewSet):
    """CRUD for Columns with filtering by service."""
    queryset = Column.objects.all()
    serializer_class = ColumnSerializer
    pagination_class = StandardResultsSetPagination
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'key']
    filterset_fields = ['service', 'field_type', 'is_active', 'required']
    ordering_fields = ['order', 'name', 'id']
    ordering = ['order', 'id']
