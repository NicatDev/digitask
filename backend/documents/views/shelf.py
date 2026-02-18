from rest_framework import viewsets, status
from rest_framework.response import Response
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
        
        # Filter by is_active
        is_active = self.request.query_params.get('is_active')
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Search by name
        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(name__icontains=search)
        
        return queryset
    
    def destroy(self, request, *args, **kwargs):
        """Soft delete - set is_active to False."""
        instance = self.get_object()
        instance.is_active = False
        instance.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
