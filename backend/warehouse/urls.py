from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    WarehouseViewSet,
    ProductViewSet,
    WarehouseInventoryViewSet,
    StockMovementViewSet,
    ProductCategoryViewSet,
    SerialNumberItemViewSet
)

router = DefaultRouter()
router.register(r'warehouses', WarehouseViewSet)
router.register(r'products', ProductViewSet)
router.register(r'inventory', WarehouseInventoryViewSet)
router.register(r'movements', StockMovementViewSet)
router.register(r'categories', ProductCategoryViewSet)
router.register(r'serial-items', SerialNumberItemViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
