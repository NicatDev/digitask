from rest_framework import serializers
from ..models import Warehouse, Product, ProductCategory, CategoryField


class WarehouseSerializer(serializers.ModelSerializer):
    region_name = serializers.CharField(source='region.name', read_only=True)

    class Meta:
        model = Warehouse
        fields = [
            'id', 'name', 'region', 'region_name', 'is_active',
            'address', 'coordinates', 'note'
        ]


class CategoryFieldSerializer(serializers.ModelSerializer):
    class Meta:
        model = CategoryField
        fields = ['id', 'category', 'name', 'field_type', 'is_required']


class ProductCategorySerializer(serializers.ModelSerializer):
    fields_list = CategoryFieldSerializer(source='fields', many=True, read_only=True)

    class Meta:
        model = ProductCategory
        fields = ['id', 'name', 'is_active', 'fields_list']


class ProductSerializer(serializers.ModelSerializer):
    unit_display = serializers.CharField(source='get_unit_display', read_only=True)
    total_stock = serializers.DecimalField(max_digits=18, decimal_places=3, read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True, default=None)
    serial_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Product
        fields = [
            'id', 'name', 'description', 'unit', 'unit_display',
            'image', 'brand', 'model', 'has_serial_number', 'port_count',
            'size', 'weight', 'price', 'note',
            'min_quantity', 'max_quantity', 'total_stock', 'is_active',
            'category', 'category_name', 'category_data', 'serial_count'
        ]
