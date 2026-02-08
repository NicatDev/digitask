from rest_framework import serializers
import json
from ..models import Task, TaskService, TaskServiceValue, Column, Service, TaskProduct, TaskType
from .product import TaskProductSerializer
from documents.serializers import TaskDocumentSerializer
from .task_type import TaskTypeSerializer


class TaskServiceValueSerializer(serializers.ModelSerializer):
    column_name = serializers.CharField(source='column.name', read_only=True)
    column_key = serializers.CharField(source='column.key', read_only=True)
    column_type = serializers.CharField(source='column.field_type', read_only=True)
    value = serializers.SerializerMethodField()
    
    class Meta:
        model = TaskServiceValue
        fields = [
            'id', 'column', 'column_name', 'column_key', 'column_type',
            'charfield_value', 'text_value', 'image_value', 'file_value',
            'date_value', 'datetime_value', 'number_value', 'decimal_value',
            'boolean_value', 'value'
        ]
        read_only_fields = ['id']
    
    def get_value(self, obj):
        return obj.get_value()


class TaskServiceSerializer(serializers.ModelSerializer):
    service_name = serializers.CharField(source='service.name', read_only=True)
    service_icon = serializers.CharField(source='service.icon', read_only=True)
    values = TaskServiceValueSerializer(many=True, read_only=True)
    values_data = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)
    values_json = serializers.JSONField(write_only=True, required=False)
    
    class Meta:
        model = TaskService
        fields = ['id', 'task', 'service', 'service_name', 'service_icon', 'note', 'values', 'values_data', 'values_json', 'created_at']
        read_only_fields = ['id', 'created_at']
    
    def create(self, validated_data):
        values_data = validated_data.pop('values_data', [])
        values_json = validated_data.pop('values_json', None)
        
        # Merge values_json into values_data if present
        if values_json:
            if isinstance(values_json, str):
                try:
                    values_json = json.loads(values_json)
                except json.JSONDecodeError:
                    values_json = []

            request = self.context.get('request')
            for item in values_json:
                if not isinstance(item, dict):
                    continue
                column_id = item.get('column')
                if column_id:
                    # Check for file in request.FILES using key 'file_{column_id}'
                    file_key = f"file_{column_id}"
                    if request and file_key in request.FILES:
                        try:
                            column = Column.objects.get(id=column_id)
                            if column.field_type == 'image':
                                item['image_value'] = request.FILES[file_key]
                            elif column.field_type == 'file':
                                item['file_value'] = request.FILES[file_key]
                        except Column.DoesNotExist:
                            pass
                values_data.append(item)

        task_service = TaskService.objects.create(**validated_data)
        
        for value_data in values_data:
            column_id = value_data.pop('column', None)
            if column_id:
                TaskServiceValue.objects.create(
                    task_service=task_service,
                    column_id=column_id,
                    **value_data
                )
        
        return task_service

    def update(self, instance, validated_data):
        values_data = validated_data.pop('values_data', [])
        values_json = validated_data.pop('values_json', None)
        
        # Merge values_json into values_data if present
        if values_json:
            if isinstance(values_json, str):
                try:
                    values_json = json.loads(values_json)
                except json.JSONDecodeError:
                    values_json = []
            
            request = self.context.get('request')
            for item in values_json:
                if not isinstance(item, dict):
                    continue
                column_id = item.get('column')
                if column_id:
                    file_key = f"file_{column_id}"
                    if request and file_key in request.FILES:
                        try:
                            column = Column.objects.get(id=column_id)
                            if column.field_type == 'image':
                                item['image_value'] = request.FILES[file_key]
                            elif column.field_type == 'file':
                                item['file_value'] = request.FILES[file_key]
                        except Column.DoesNotExist:
                            pass
                values_data.append(item)
        
        # Update main instance fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update or Create values
        for value_data in values_data:
            column_id = value_data.pop('column', None)
            if column_id:
                TaskServiceValue.objects.update_or_create(
                    task_service=instance,
                    column_id=column_id,
                    defaults=value_data
                )
        
        return instance


class TaskSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.full_name', read_only=True)
    customer_address = serializers.CharField(source='customer.address', read_only=True)
    customer_coordinates = serializers.JSONField(source='customer.address_coordinates', read_only=True)
    customer_phone = serializers.CharField(source='customer.phone_number', read_only=True)
    customer_register_number = serializers.CharField(source='customer.register_number', read_only=True)
    assigned_to_name = serializers.SerializerMethodField()
    group_name = serializers.CharField(source='group.name', read_only=True)
    region_name = serializers.CharField(source='group.region.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    task_services = TaskServiceSerializer(many=True, read_only=True)
    task_products = TaskProductSerializer(many=True, read_only=True)
    task_documents = TaskDocumentSerializer(many=True, read_only=True)
    task_type_details = TaskTypeSerializer(source='task_type', read_only=True)
    task_type = serializers.PrimaryKeyRelatedField(queryset=TaskType.objects.filter(is_active=True), allow_null=True, required=False)
    services = serializers.PrimaryKeyRelatedField(many=True, queryset=Service.objects.all(), required=False)

    class Meta:
        model = Task
        fields = [
            'id', 'customer', 'customer_name', 'customer_address', 'customer_coordinates',
            'customer_phone', 'customer_register_number',
            'title', 'note', 'status', 'status_display',
            'assigned_to', 'assigned_to_name',
            'group', 'group_name', 'region_name', 'is_active', 
            'task_type', 'task_type_details',
            'services', 'task_services', 'task_products', 'task_documents', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def create(self, validated_data):
        services = validated_data.pop('services', [])
        task = Task.objects.create(**validated_data)
        task.services.set(services)
        return task
    
    def update(self, instance, validated_data):
        services = validated_data.pop('services', None)
        
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if services is not None:
             instance.services.set(services)
        
        return instance


    def get_assigned_to_name(self, obj):
        if not obj.assigned_to:
            return None
        full_name = obj.assigned_to.get_full_name()
        return full_name if full_name else obj.assigned_to.username


class TaskStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Task.Status.choices)
