from rest_framework import serializers
from django.db.models import Count
from ..models import Shelf


class ShelfSerializer(serializers.ModelSerializer):
    document_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Shelf
        fields = ['id', 'name', 'location', 'description', 'document_count', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
