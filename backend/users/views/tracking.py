from rest_framework import viewsets, permissions, response
from rest_framework.decorators import action
from ..models import UserLocation, LocationHistory
from ..serializers.tracking import UserLocationSerializer, LocationHistorySerializer
from warehouse.models.common import Warehouse

class LiveMapViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request):
        """
        Return all users with location profiles, and all warehouses.
        """
        locations = UserLocation.objects.select_related('user', 'user__role').all()
        # Ensure every user has a location profile?
        # Ideally we create it on signal, but for now filtering existing.
        
        user_data = UserLocationSerializer(locations, many=True).data
        
        warehouses = Warehouse.objects.filter(is_active=True)
        warehouse_data = [
            {
                'id': w.id, 
                'name': w.name, 
                'lat': w.coordinates.get('lat'), 
                'lng': w.coordinates.get('lng'),
                'type': 'warehouse'
            }
            for w in warehouses
        ]
        
        return response.Response({
            'users': user_data,
            'warehouses': warehouse_data
        })

    @action(detail=True, methods=['get'])
    def history(self, request, pk=None):        
        hours = int(request.query_params.get('hours', 1))
        
        from django.utils import timezone
        import datetime
        since = timezone.now() - datetime.timedelta(hours=hours)
        
        history = LocationHistory.objects.filter(user_id=pk, timestamp__gte=since).order_by('timestamp')
        data = LocationHistorySerializer(history, many=True).data
        return response.Response(data)
