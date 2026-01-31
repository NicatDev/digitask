from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from ..models import User, Role
from ..serializers import UserSerializer, RoleSerializer

class BaseSoftDeleteViewSet(viewsets.ModelViewSet):
    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()
    
    # def get_queryset(self):
    #     return super().get_queryset().filter(is_active=True)

class RoleViewSet(BaseSoftDeleteViewSet):
    queryset = Role.objects.all()
    serializer_class = RoleSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'description']

class UserViewSet(BaseSoftDeleteViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['username', 'email', 'first_name', 'last_name']

    @action(detail=True, methods=['post'])
    def change_password(self, request, pk=None):
        user = self.get_object()
        password = request.data.get('password')
        if password:
            user.set_password(password)
            user.save()
            return Response({'status': 'password set'})
        return Response({'error': 'password required'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'])
    def me(self, request):
        serializer = self.get_serializer(request.user)
        # We can add permissions here if needed
        data = serializer.data
        # data['permissions'] = ... # If granular permissions needed
        return Response(data)
