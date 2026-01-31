from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ServiceViewSet, ColumnViewSet, CustomerViewSet, TaskViewSet, TaskServiceViewSet, NotificationViewSet

router = DefaultRouter()
router.register(r'services', ServiceViewSet)
router.register(r'columns', ColumnViewSet)
router.register(r'customers', CustomerViewSet)
router.register(r'tasks', TaskViewSet)
router.register(r'task-services', TaskServiceViewSet)
router.register(r'notifications', NotificationViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]
