from rest_framework import serializers
from ..models import Equipment, OpticBox


class EquipmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Equipment
        fields = ["id", "name", "description", "is_active", "created_at"]
        read_only_fields = ["id", "created_at"]


class OpticBoxSerializer(serializers.ModelSerializer):
    class Meta:
        model = OpticBox
        fields = ["id", "name", "description", "is_active", "created_at"]
        read_only_fields = ["id", "created_at"]
