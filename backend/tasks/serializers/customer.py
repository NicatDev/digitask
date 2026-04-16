from rest_framework import serializers
from ..models import Customer, CustomerImportJob


class CustomerSerializer(serializers.ModelSerializer):
    region_name = serializers.CharField(source='region.name', read_only=True)
    equipment_name = serializers.CharField(source='equipment.name', read_only=True, allow_null=True)
    optic_box_name = serializers.CharField(source='optic_box.name', read_only=True, allow_null=True)

    class Meta:
        model = Customer
        fields = [
            'id', 'full_name', 'register_number', 'phone_number',
            'passport_image', 'region', 'region_name',
            'equipment', 'equipment_name', 'optic_box', 'optic_box_name',
            'address',
            'address_coordinates', 'bulk_created', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class CustomerOptionSerializer(serializers.ModelSerializer):
    label = serializers.SerializerMethodField()

    class Meta:
        model = Customer
        fields = ['id', 'full_name', 'register_number', 'is_active', 'label']

    def get_label(self, obj):
        if obj.register_number:
            return f"{obj.full_name} - {obj.register_number}"
        return obj.full_name


class CustomerImportJobSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomerImportJob
        fields = [
            "id",
            "status",
            "total_rows",
            "processed_rows",
            "created_count",
            "skipped_count",
            "error_count",
            "sample_errors",
            "started_at",
            "finished_at",
            "duration_ms",
            "created_at",
        ]
