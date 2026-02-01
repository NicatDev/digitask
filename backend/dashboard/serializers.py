from rest_framework import serializers
from .models import Event

class EventSerializer(serializers.ModelSerializer):
    event_type_display = serializers.CharField(source='get_event_type_display', read_only=True)

    class Meta:
        model = Event
        fields = ['id', 'title', 'description', 'event_type', 'event_type_display', 'date', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']
