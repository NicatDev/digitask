from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import EventViewSet, DashboardStatsView

router = DefaultRouter()
router.register(r'events', EventViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('stats/', DashboardStatsView.as_view(), name='dashboard-stats'),
]
