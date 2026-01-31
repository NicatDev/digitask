from rest_framework import serializers
from ..models import Service, Column


class ColumnSerializer(serializers.ModelSerializer):
    service_name = serializers.CharField(source='service.name', read_only=True)
    field_type_display = serializers.CharField(source='get_field_type_display', read_only=True)

    class Meta:
        model = Column
        fields = [
            'id', 'service', 'service_name', 'name', 'key', 'field_type', 
            'field_type_display', 'required', 'is_active', 'min_value', 
            'max_value', 'order'
        ]
        read_only_fields = ['id']


class ServiceSerializer(serializers.ModelSerializer):
    columns = ColumnSerializer(many=True, read_only=True)
    columns_count = serializers.SerializerMethodField()

    class Meta:
        model = Service
        fields = ['id', 'name', 'icon', 'description', 'is_active', 'columns', 'columns_count']
        read_only_fields = ['id']

    def get_columns_count(self, obj):
        return obj.columns.filter(is_active=True).count()
