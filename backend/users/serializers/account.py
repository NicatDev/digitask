from rest_framework import serializers
from ..models import User, Role
from ..task_permissions import (
    build_role_description,
    get_task_permissions_for_user,
    get_task_status_permissions_for_user,
    get_task_status_visibility_for_user,
    parse_role_description,
)

class RoleSerializer(serializers.ModelSerializer):
    task_permissions = serializers.JSONField(required=False)
    task_status_visibility = serializers.JSONField(required=False)
    task_status_permissions = serializers.JSONField(required=False)

    class Meta:
        model = Role
        fields = [
            'id', 'name', 'description', 'is_active',
            'is_task_reader', 'is_task_writer', 'is_task_view_all',
            'is_document_reader', 'is_document_writer',
            'is_warehouse_reader', 'is_warehouse_writer',
            'is_admin', 'is_super_admin',
            'task_permissions', 'task_status_visibility', 'task_status_permissions',
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        parsed = parse_role_description(instance.description)
        data['description'] = parsed.get('text') or ''
        data['task_permissions'] = parsed.get('task_permissions') or {}
        data['task_status_visibility'] = parsed.get('task_status_visibility') or {}
        data['task_status_permissions'] = parsed.get('task_status_permissions') or {}
        return data

    def create(self, validated_data):
        task_permissions = validated_data.pop('task_permissions', {})
        task_status_visibility = validated_data.pop('task_status_visibility', {})
        task_status_permissions = validated_data.pop('task_status_permissions', {})
        description_text = validated_data.pop('description', '')
        validated_data['description'] = build_role_description(
            description_text,
            task_permissions,
            task_status_visibility,
            task_status_permissions,
        )
        return super().create(validated_data)

    def update(self, instance, validated_data):
        parsed = parse_role_description(instance.description)
        if 'task_permissions' in validated_data:
            parsed['task_permissions'] = validated_data.pop('task_permissions') or {}
        if 'task_status_visibility' in validated_data:
            parsed['task_status_visibility'] = validated_data.pop('task_status_visibility') or {}
        if 'task_status_permissions' in validated_data:
            parsed['task_status_permissions'] = validated_data.pop('task_status_permissions') or {}
        if 'description' in validated_data:
            parsed['text'] = validated_data.pop('description') or ''
        validated_data['description'] = build_role_description(
            parsed.get('text') or '',
            parsed.get('task_permissions') or {},
            parsed.get('task_status_visibility') or {},
            parsed.get('task_status_permissions') or {},
        )
        return super().update(instance, validated_data)

class UserSerializer(serializers.ModelSerializer):
    role_name = serializers.CharField(source='role.name', read_only=True)
    group_name = serializers.CharField(source='group.name', read_only=True)
    
    # Flattened Permissions from Role
    is_task_reader = serializers.BooleanField(source='role.is_task_reader', read_only=True)
    is_task_writer = serializers.BooleanField(source='role.is_task_writer', read_only=True)
    is_task_view_all = serializers.BooleanField(source='role.is_task_view_all', read_only=True)
    is_warehouse_reader = serializers.BooleanField(source='role.is_warehouse_reader', read_only=True)
    is_warehouse_writer = serializers.BooleanField(source='role.is_warehouse_writer', read_only=True)
    is_document_reader = serializers.BooleanField(source='role.is_document_reader', read_only=True)
    is_document_writer = serializers.BooleanField(source='role.is_document_writer', read_only=True)
    is_admin = serializers.BooleanField(source='role.is_admin', read_only=True)
    is_super_admin = serializers.BooleanField(source='role.is_super_admin', read_only=True)
    task_permissions = serializers.SerializerMethodField()
    task_status_visibility = serializers.SerializerMethodField()
    task_status_permissions = serializers.SerializerMethodField()
    
    is_online = serializers.SerializerMethodField()
    last_seen = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'phone_number', 'avatar', 'first_name', 'last_name', 
            'role', 'role_name', 'group', 'group_name', 'is_active', 'password', 'address', 'address_coordinates',
            'is_task_reader', 'is_task_writer', 'is_task_view_all', 'is_warehouse_reader', 'is_warehouse_writer',
            'is_document_reader', 'is_document_writer', 'is_admin', 'is_super_admin',
            'task_permissions', 'task_status_visibility', 'task_status_permissions',
            'task_table_column_visibility',
            'is_online', 'last_seen'
        ]
        extra_kwargs = {'password': {'write_only': True, 'required': False}}

    def get_is_online(self, obj):
        # Check if attribute exists (avoid RelatedObjectDoesNotExist)
        if hasattr(obj, 'location_profile'):
            return obj.location_profile.is_online
        return False

    def get_last_seen(self, obj):
        if hasattr(obj, 'location_profile'):
            return obj.location_profile.last_seen
        return None

    def get_task_permissions(self, obj):
        return get_task_permissions_for_user(obj)

    def get_task_status_visibility(self, obj):
        return get_task_status_visibility_for_user(obj)

    def get_task_status_permissions(self, obj):
        return get_task_status_permissions_for_user(obj)

    def validate_task_table_column_visibility(self, value):
        if value is None:
            return {}
        if not isinstance(value, dict):
            raise serializers.ValidationError('Obyekt olmalıdır.')
        return {str(k): bool(v) for k, v in value.items()}

    def create(self, validated_data):
        user = User.objects.create_user(**validated_data)
        return user

    def update(self, instance, validated_data):
        if 'password' in validated_data:
            password = validated_data.pop('password')
            instance.set_password(password)
        return super().update(instance, validated_data)
