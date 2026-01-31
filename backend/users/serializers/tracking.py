from rest_framework import serializers
from ..models import UserLocation, LocationHistory, User
from tasks.models import Task

class UserLocationSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id')
    full_name = serializers.CharField(source='user.get_full_name')
    avatar = serializers.ImageField(source='user.avatar')
    role = serializers.CharField(source='user.role.name', default='')
    
    active_tasks = serializers.SerializerMethodField()
    
    class Meta:
        model = UserLocation
        fields = ['user_id', 'full_name', 'avatar', 'role', 'latitude', 'longitude', 'is_online', 'last_seen', 'active_tasks']
        
    def get_active_tasks(self, obj):
        # Find all active tasks for this user
        # Task status IN_PROGRESS or ARRIVED
        
        tasks = Task.objects.filter(
            assigned_to=obj.user, 
            status__in=['in_progress', 'arrived']
        ).select_related('customer')
        
        result = []
        for task in tasks:
            if task.customer and task.customer.address_coordinates:
                coords = task.customer.address_coordinates
                if coords.get('lat') and coords.get('lng'):
                    result.append({
                        'id': task.id,
                        'customer_name': task.customer.full_name,
                        'customer_lat': coords.get('lat'),
                        'customer_lng': coords.get('lng'),
                        'customer_address': task.customer.address
                    })
        return result

class LocationHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LocationHistory
        fields = ['latitude', 'longitude', 'timestamp']
