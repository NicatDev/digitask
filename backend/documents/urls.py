from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ShelfViewSet, TaskDocumentViewSet

router = DefaultRouter()
router.register(r'documents', TaskDocumentViewSet)
router.register(r'shelves', ShelfViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
