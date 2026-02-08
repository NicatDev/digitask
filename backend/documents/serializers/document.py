from rest_framework import serializers
from ..models import TaskDocument


class TaskDocumentSerializer(serializers.ModelSerializer):
    file_url = serializers.SerializerMethodField()
    confirmed_by_name = serializers.CharField(source='confirmed_by.get_full_name', read_only=True)
    shelf_name = serializers.CharField(source='shelf.name', read_only=True)
    task_title = serializers.CharField(source='task.title', read_only=True)

    class Meta:
        model = TaskDocument
        fields = [
            'id', 'task', 'task_title', 'stock_movement', 'action', 'shelf', 'shelf_name',
            'title', 'file', 'file_url', 
            'confirmed', 'confirmed_by', 'confirmed_by_name', 'confirmed_at',
            'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'confirmed_by', 'confirmed_at']
    
    def get_file_url(self, obj):
        request = self.context.get('request')
        if obj.file and request:
            return request.build_absolute_uri(obj.file.url)
        return None
