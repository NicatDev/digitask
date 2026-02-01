from rest_framework import serializers
from ..models import User, Role

class RoleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Role
        fields = '__all__'

class UserSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source='role.name', read_only=True)
    group_name = serializers.CharField(source='group.name', read_only=True)
    
    # Flattened Permissions from Role
    is_task_reader = serializers.BooleanField(source='role.is_task_reader', read_only=True)
    is_task_writer = serializers.BooleanField(source='role.is_task_writer', read_only=True)
    is_warehouse_reader = serializers.BooleanField(source='role.is_warehouse_reader', read_only=True)
    is_warehouse_writer = serializers.BooleanField(source='role.is_warehouse_writer', read_only=True)
    is_document_reader = serializers.BooleanField(source='role.is_document_reader', read_only=True)
    is_document_writer = serializers.BooleanField(source='role.is_document_writer', read_only=True)
    is_admin = serializers.BooleanField(source='role.is_admin', read_only=True)
    is_super_admin = serializers.BooleanField(source='role.is_super_admin', read_only=True)

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'phone_number', 'avatar', 'first_name', 'last_name', 
            'role', 'role_name', 'group', 'group_name', 'is_active', 'password', 'address', 'address_coordinates',
            'is_task_reader', 'is_task_writer', 'is_warehouse_reader', 'is_warehouse_writer',
            'is_document_reader', 'is_document_writer', 'is_admin', 'is_super_admin'
        ]
        extra_kwargs = {'password': {'write_only': True, 'required': False}}

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user

    def update(self, instance, validated_data):
        if 'password' in validated_data:
            password = validated_data.pop('password')
            instance.set_password(password)
        return super().update(instance, validated_data)
