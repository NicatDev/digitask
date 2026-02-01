from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from ..models import TaskType
from ..serializers.task_type import TaskTypeSerializer

class TaskTypeViewSet(viewsets.ModelViewSet):
    queryset = TaskType.objects.filter(is_active=True)
    serializer_class = TaskTypeSerializer
    permission_classes = [IsAuthenticated]
    
    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()
