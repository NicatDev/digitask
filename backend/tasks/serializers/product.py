from rest_framework import serializers
from ..models import TaskProduct


class TaskProductSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_unit = serializers.CharField(source='product.unit', read_only=True)
    warehouse_name = serializers.CharField(source='warehouse.name', read_only=True)

    class Meta:
        model = TaskProduct
        fields = [
            'id', 'task', 'product', 'product_name', 'product_unit',
            'warehouse', 'warehouse_name', 'quantity', 'is_deducted', 'created_at'
        ]
        read_only_fields = ['id', 'is_deducted', 'created_at']


class TaskProductCreateSerializer(serializers.Serializer):
    """Toplu TaskProduct yaratmaq üçün serializer"""
    products = serializers.ListField(
        child=serializers.DictField(),
        required=True
    )
    # products = [{"product_id": 1, "warehouse_id": 1, "quantity": 2}, ...]
