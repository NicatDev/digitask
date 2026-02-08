from rest_framework import serializers
from ..models import Warehouse, Product

class WarehouseSerializer(serializers.ModelSerializer):
    region_name = serializers.CharField(source='region.name', read_only=True)

    class Meta:
        model = Warehouse
        fields = [
            'id', 'name', 'region', 'region_name', 'is_active',
            'address', 'coordinates', 'note'
        ]

class ProductSerializer(serializers.ModelSerializer):
    unit_display = serializers.CharField(source='get_unit_display', read_only=True)
    total_stock = serializers.DecimalField(max_digits=18, decimal_places=3, read_only=True)

    class Meta:
        model = Product
        fields = [
            'id', 'name', 'description', 'unit', 'unit_display',
            'image', 'brand', 'model', 'serial_number', 'port_count',
            'size', 'weight', 'price', 'note',
            'min_quantity', 'max_quantity', 'total_stock', 'is_active'
        ]
