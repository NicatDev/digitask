from rest_framework import serializers
from .models import Event, EventImage


class EventSerializer(serializers.ModelSerializer):
    event_type_display = serializers.CharField(source='get_event_type_display', read_only=True)
    images = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            'id', 'title', 'description', 'event_type', 'event_type_display',
            'image', 'images', 'date', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'event_type_display', 'image', 'images']

    def get_images(self, obj):
        request = self.context.get('request')
        out = []
        for ei in obj.event_images.all().order_by('-created_at'):
            if not ei.image:
                continue
            url = ei.image.url
            if request:
                url = request.build_absolute_uri(url)
            out.append({'id': ei.id, 'image': url, 'created_at': ei.created_at})
        if not out and obj.image:
            url = obj.image.url
            if request:
                url = request.build_absolute_uri(url)
            out.append({'id': None, 'image': url, 'created_at': obj.created_at})
        return out

    def get_image(self, obj):
        imgs = self.get_images(obj)
        return imgs[0]['image'] if imgs else None

    def create(self, validated_data):
        request = self.context['request']
        event = Event.objects.create(**validated_data)
        files = list(request.FILES.getlist('images'))
        if not files and request.FILES.get('image'):
            files = [request.FILES['image']]
        for f in files:
            EventImage.objects.create(event=event, image=f)
        return event
