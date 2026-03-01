from rest_framework import serializers
from ..models import WarehouseInventory, StockMovement, SerialNumberItem


class WarehouseInventorySerializer(serializers.ModelSerializer):
    warehouse_name = serializers.CharField(source='warehouse.name', read_only=True)
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_unit = serializers.CharField(source='product.unit', read_only=True)
    product_has_serial = serializers.BooleanField(source='product.has_serial_number', read_only=True)

    class Meta:
        model = WarehouseInventory
        fields = [
            'id', 'warehouse', 'warehouse_name', 'product', 'product_name',
            'product_unit', 'product_has_serial', 'quantity'
        ]


class SerialNumberItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    warehouse_name = serializers.CharField(source='warehouse.name', read_only=True)

    class Meta:
        model = SerialNumberItem
        fields = ['id', 'product', 'product_name', 'warehouse', 'warehouse_name', 'serial_number', 'created_at']
        read_only_fields = ['created_at']


class StockMovementSerializer(serializers.ModelSerializer):
    warehouse_name = serializers.CharField(source='warehouse.name', read_only=True)
    to_warehouse_name = serializers.CharField(source='to_warehouse.name', read_only=True, default='')
    product_name = serializers.CharField(source='product.name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    movement_type_display = serializers.CharField(source='get_movement_type_display', read_only=True)

    class Meta:
        model = StockMovement
        fields = [
            'id', 'warehouse', 'warehouse_name', 'from_warehouse', 'to_warehouse',
            'to_warehouse_name',
            'product', 'product_name', 'movement_type', 'movement_type_display',
            'reason', 'quantity_old', 'quantity_new',
            'created_by', 'created_by_name', 'created_at', 'reference_no',
            'serial_number', 'returned_by'
        ]
        read_only_fields = ['created_by', 'created_at']
