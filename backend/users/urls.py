from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from .views import RegionViewSet, GroupViewSet, RoleViewSet, UserViewSet
from .views.tracking import LiveMapViewSet

router = DefaultRouter()
router.register(r'regions', RegionViewSet)
router.register(r'groups', GroupViewSet)
router.register(r'roles', RoleViewSet)
router.register(r'users', UserViewSet)
router.register(r'live-map', LiveMapViewSet, basename='live-map')

urlpatterns = [
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('', include(router.urls)),
]
