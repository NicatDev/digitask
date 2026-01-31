from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    WarehouseViewSet,
    ProductViewSet,
    WarehouseInventoryViewSet,
    StockMovementViewSet
)

router = DefaultRouter()
router.register(r'warehouses', WarehouseViewSet)
router.register(r'products', ProductViewSet)
router.register(r'inventory', WarehouseInventoryViewSet)
router.register(r'movements', StockMovementViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
