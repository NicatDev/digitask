from rest_framework import serializers
from ..models import Customer
from users.models import Region


class CustomerSerializer(serializers.ModelSerializer):
    region_name = serializers.CharField(source='region.name', read_only=True)
    
    class Meta:
        model = Customer
        fields = [
            'id', 'full_name', 'register_number', 'phone_number', 
            'passport_image', 'region', 'region_name', 'address', 
            'address_coordinates', 'is_active', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']
