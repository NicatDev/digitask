from rest_framework import serializers
from ..models import Task, TaskService, TaskServiceValue, Column


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
    
    class Meta:
        model = TaskService
        fields = ['id', 'task', 'service', 'service_name', 'service_icon', 'note', 'values', 'values_data', 'created_at']
        read_only_fields = ['id', 'created_at']
    
    def create(self, validated_data):
        values_data = validated_data.pop('values_data', [])
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


class TaskSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.full_name', read_only=True)
    assigned_to_name = serializers.CharField(source='assigned_to.username', read_only=True)
    group_name = serializers.CharField(source='group.name', read_only=True)
    region_name = serializers.CharField(source='group.region.name', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    task_services = TaskServiceSerializer(many=True, read_only=True)
    services_data = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)
    
    class Meta:
        model = Task
        fields = [
            'id', 'customer', 'customer_name', 'title', 'note', 'status', 'status_display',
            'latitude', 'longitude', 'assigned_to', 'assigned_to_name',
            'group', 'group_name', 'region_name', 'is_active', 
            'task_services', 'services_data', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def create(self, validated_data):
        services_data = validated_data.pop('services_data', [])
        task = Task.objects.create(**validated_data)
        
        for service_data in services_data:
            service_id = service_data.get('service')
            note = service_data.get('note', '')
            values_data = service_data.get('values', [])
            
            task_service = TaskService.objects.create(
                task=task,
                service_id=service_id,
                note=note
            )
            
            for value_data in values_data:
                column_id = value_data.pop('column', None)
                if column_id:
                    TaskServiceValue.objects.create(
                        task_service=task_service,
                        column_id=column_id,
                        **value_data
                    )
        
        return task
    
    def update(self, instance, validated_data):
        services_data = validated_data.pop('services_data', None)
        
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if services_data is not None:
            # Delete old services and recreate
            instance.task_services.all().delete()
            
            for service_data in services_data:
                service_id = service_data.get('service')
                note = service_data.get('note', '')
                values_data = service_data.get('values', [])
                
                task_service = TaskService.objects.create(
                    task=instance,
                    service_id=service_id,
                    note=note
                )
                
                for value_data in values_data:
                    column_id = value_data.pop('column', None)
                    if column_id:
                        TaskServiceValue.objects.create(
                            task_service=task_service,
                            column_id=column_id,
                            **value_data
                        )
        
        return instance


class TaskStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Task.Status.choices)
