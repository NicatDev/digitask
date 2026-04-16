from django.db.models import Q
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from ..models import Customer
from ..serializers import CustomerSerializer, CustomerOptionSerializer
from rest_framework.pagination import PageNumberPagination

class CustomerPagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 100

class CustomerViewSet(viewsets.ModelViewSet):
    """ViewSet for Customer CRUD operations."""
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    pagination_class = CustomerPagination
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Customer.objects.select_related(
            'region', 'equipment', 'optic_box'
        ).order_by('-created_at')

        region = self.request.query_params.get('region')
        if region:
            queryset = queryset.filter(region_id=region)

        equipment = self.request.query_params.get('equipment')
        if equipment:
            queryset = queryset.filter(equipment_id=equipment)

        optic_box = self.request.query_params.get('optic_box')
        if optic_box:
            queryset = queryset.filter(optic_box_id=optic_box)

        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(full_name__icontains=search) |
                Q(register_number__icontains=search) |
                Q(phone_number__icontains=search)
            )

        return queryset

    @action(detail=False, methods=['get'], url_path='options')
    def options(self, request):
        """
        Optimized endpoint for customer selects (mobile/web).
        Supports backend search + pagination for infinite scroll.
        """
        qs = Customer.objects.all().only('id', 'full_name', 'register_number', 'is_active')

        is_active = request.query_params.get('is_active')
        if is_active is not None:
            qs = qs.filter(is_active=is_active.lower() == 'true')

        search = request.query_params.get('search')
        if search:
            qs = qs.filter(
                Q(full_name__icontains=search) | Q(register_number__icontains=search)
            )

        qs = qs.order_by('full_name', 'id')

        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = CustomerOptionSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = CustomerOptionSerializer(qs, many=True)
        return Response(serializer.data)
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False."""
        instance = self.get_object()
        instance.is_active = False
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
