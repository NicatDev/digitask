from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from django.db import models
from django.db.models import Count
from ..models import Shelf
from ..serializers import ShelfSerializer


class ShelfViewSet(viewsets.ModelViewSet):
    """ViewSet for Shelf CRUD operations."""
    queryset = Shelf.objects.all()
    serializer_class = ShelfSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        queryset = Shelf.objects.annotate(
            document_count=Count('documents', filter=models.Q(documents__confirmed=True))
        ).order_by('name')
        
        # Search by name
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(name__icontains=search)
        
        return queryset
