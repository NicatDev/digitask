from django.db.models import Q
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from ..models import Customer, CustomerImportJob
from ..serializers import (
    CustomerSerializer,
    CustomerOptionSerializer,
    CustomerImportJobSerializer,
)
from rest_framework.pagination import PageNumberPagination
from ..services.customer_import import start_customer_import_job

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

    def _is_admin_like(self, user):
        role = getattr(user, "role", None)
        return bool(
            user.is_superuser
            or (role and role.is_admin)
            or (role and role.is_super_admin)
        )

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

    @action(detail=False, methods=["post"], url_path="import/start")
    def import_start(self, request):
        if not self._is_admin_like(request.user):
            return Response(
                {"detail": "Bu əməliyyat üçün icazəniz yoxdur."},
                status=status.HTTP_403_FORBIDDEN,
            )

        active_job = CustomerImportJob.objects.filter(
            status__in=[CustomerImportJob.Status.PENDING, CustomerImportJob.Status.RUNNING]
        ).first()
        if active_job:
            return Response(
                {
                    "detail": "Hazırda aktiv import var.",
                    "job_id": str(active_job.id),
                },
                status=status.HTTP_409_CONFLICT,
            )

        job = CustomerImportJob.objects.create(
            status=CustomerImportJob.Status.PENDING,
            triggered_by=request.user,
        )
        start_customer_import_job(job.id)
        return Response({"job_id": str(job.id)}, status=status.HTTP_202_ACCEPTED)

    @action(detail=False, methods=["get"], url_path=r"import/(?P<job_id>[^/.]+)")
    def import_status(self, request, job_id=None):
        if not self._is_admin_like(request.user):
            return Response(
                {"detail": "Bu əməliyyat üçün icazəniz yoxdur."},
                status=status.HTTP_403_FORBIDDEN,
            )
        job = CustomerImportJob.objects.filter(pk=job_id).first()
        if not job:
            return Response({"detail": "Job tapılmadı."}, status=status.HTTP_404_NOT_FOUND)
        return Response(CustomerImportJobSerializer(job).data)
