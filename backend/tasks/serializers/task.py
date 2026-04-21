from rest_framework import serializers
from django.contrib.auth import get_user_model
import json
from ..models import Task, TaskService, TaskServiceValue, Column, Service, TaskProduct, TaskType
from .product import TaskProductSerializer
from documents.serializers import TaskDocumentSerializer
from .task_type import TaskTypeSerializer

User = get_user_model()


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
    customer_equipment_name = serializers.CharField(
        source='customer.equipment.name', read_only=True, allow_null=True
    )
    customer_optic_box_name = serializers.CharField(
        source='customer.optic_box.name', read_only=True, allow_null=True
    )
    assigned_to = serializers.PrimaryKeyRelatedField(many=True, queryset=User.objects.all(), required=False)
    assigned_to_names = serializers.SerializerMethodField()
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
            'customer_equipment_name', 'customer_optic_box_name',
            'title', 'note', 'status', 'status_display',
            'rescheduled_date',
            'assigned_to', 'assigned_to_names',
            'group', 'group_name', 'region_name', 'is_active',
            'task_type', 'task_type_details',
            'services', 'task_services', 'task_products', 'task_documents', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('status') == 'arrived':
            data['status'] = Task.Status.IN_PROGRESS
            data['status_display'] = Task.Status.IN_PROGRESS.label
        return data

    def validate(self, attrs):
        status = attrs.get('status', self.instance.status if self.instance else Task.Status.TODO)
        if status == Task.Status.PENDING:
            if 'rescheduled_date' in attrs:
                rd = attrs['rescheduled_date']
            else:
                rd = self.instance.rescheduled_date if self.instance else None
            if not rd:
                raise serializers.ValidationError(
                    {'rescheduled_date': 'Təxirə salındı üçün tarix seçin (Rescheduled date).'}
                )
        return attrs
    
    def create(self, validated_data):
        services = validated_data.pop('services', [])
        assigned_users = validated_data.pop('assigned_to', [])
        task = Task.objects.create(**validated_data)
        task.services.set(services)
        task.assigned_to.set(assigned_users)
        return task
    
    def update(self, instance, validated_data):
        services = validated_data.pop('services', None)
        assigned_users = validated_data.pop('assigned_to', None)
        new_status = validated_data.get('status', instance.status)
        if new_status != Task.Status.PENDING:
            validated_data['rescheduled_date'] = None

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        if services is not None:
             instance.services.set(services)
        
        if assigned_users is not None:
            instance.assigned_to.set(assigned_users)
        
        return instance

    def get_assigned_to_names(self, obj):
        users = obj.assigned_to.all()
        if not users:
            return []
        result = []
        for user in users:
            full_name = user.get_full_name()
            result.append(full_name if full_name else user.username)
        return result


class TaskStatusUpdateSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Task.Status.choices)
    rescheduled_date = serializers.DateField(required=False, allow_null=True)
    reject_note = serializers.CharField(required=False, allow_blank=False, trim_whitespace=True)

    def validate(self, attrs):
        st = attrs['status']
        rd = attrs.get('rescheduled_date')
        if st == Task.Status.PENDING:
            if not rd:
                raise serializers.ValidationError(
                    {'rescheduled_date': 'Təxirə salındı üçün tarix seçin (Rescheduled date).'}
                )
        if st == Task.Status.REJECTED:
            note = (attrs.get('reject_note') or '').strip()
            if not note:
                raise serializers.ValidationError({'reject_note': 'Rədd etmə səbəbi (reject note) mütləqdir.'})
            attrs['reject_note'] = note
        return attrs


class TaskCustomerHistorySerializer(serializers.ModelSerializer):
    """Light list for müştərinin tapşırıq tarixçəsi modalı."""

    status_display = serializers.CharField(source="get_status_display", read_only=True)
    assigned_to_names = serializers.SerializerMethodField()

    class Meta:
        model = Task
        fields = ["id", "title", "status", "status_display", "assigned_to_names", "created_at"]

    def get_assigned_to_names(self, obj):
        users = obj.assigned_to.all()
        if not users:
            return []
        result = []
        for user in users:
            full_name = user.get_full_name()
            result.append(full_name if full_name else user.username)
        return result

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('status') == 'arrived':
            data['status'] = Task.Status.IN_PROGRESS
            data['status_display'] = Task.Status.IN_PROGRESS.label
        return data
