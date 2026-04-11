from rest_framework import serializers
from ..models import Customer


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
            'address_coordinates', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']
