from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    ServiceViewSet,
    ColumnViewSet,
    EquipmentViewSet,
    OpticBoxViewSet,
    CustomerViewSet,
    TaskViewSet,
    TaskServiceViewSet,
    TaskProductViewSet,
    TaskTypeViewSet,
)

router = DefaultRouter()
router.register(r'services', ServiceViewSet)
router.register(r'columns', ColumnViewSet)
router.register(r'equipment', EquipmentViewSet)
router.register(r'optic-boxes', OpticBoxViewSet)
router.register(r'customers', CustomerViewSet)
router.register(r'tasks', TaskViewSet)
router.register(r'task-services', TaskServiceViewSet)
router.register(r'task-products', TaskProductViewSet)

router.register(r'task-types', TaskTypeViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
