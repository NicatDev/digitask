from django.db.models import Q
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from ..models import Customer
from ..serializers import CustomerSerializer
from rest_framework.pagination import PageNumberPagination

from ..pagination import TaskPagination

class CustomerMaxPagination(PageNumberPagination):
    page_size = 150

class CustomerViewSet(viewsets.ModelViewSet):
    """ViewSet for Customer CRUD operations."""
    queryset = Customer.objects.all()
    serializer_class = CustomerSerializer
    pagination_class = CustomerMaxPagination
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
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False."""
        instance = self.get_object()
        instance.is_active = False
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
