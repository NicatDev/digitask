from rest_framework import viewsets, filters
from ..models import Region, Group
from ..serializers import RegionSerializer, GroupSerializer

class BaseSoftDeleteViewSet(viewsets.ModelViewSet):
    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()
    
    # def get_queryset(self):
    #     return super().get_queryset().filter(is_active=True)

class RegionViewSet(BaseSoftDeleteViewSet):
    queryset = Region.objects.all()
    serializer_class = RegionSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name']

class GroupViewSet(BaseSoftDeleteViewSet):
    queryset = Group.objects.all()
    serializer_class = GroupSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'description', 'region__name']
