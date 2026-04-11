from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from ..models import Equipment, OpticBox
from ..serializers.equipment import EquipmentSerializer, OpticBoxSerializer
from ..pagination import TaskPagination


class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    serializer_class = EquipmentSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = TaskPagination

    def get_queryset(self):
        qs = Equipment.objects.all().order_by("name")
        is_active = self.request.query_params.get("is_active")
        if is_active is not None:
            qs = qs.filter(is_active=is_active.lower() == "true")
        return qs

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()


class OpticBoxViewSet(viewsets.ModelViewSet):
    queryset = OpticBox.objects.all()
    serializer_class = OpticBoxSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = TaskPagination

    def get_queryset(self):
        qs = OpticBox.objects.all().order_by("name")
        is_active = self.request.query_params.get("is_active")
        if is_active is not None:
            qs = qs.filter(is_active=is_active.lower() == "true")
        return qs

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()
