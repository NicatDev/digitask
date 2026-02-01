from rest_framework import serializers
from ..models import TaskType

class TaskTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = TaskType
        fields = ['id', 'name', 'description', 'color', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']
