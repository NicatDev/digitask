from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ChatGroupViewSet, MessageViewSet

router = DefaultRouter()
router.register(r'groups', ChatGroupViewSet, basename='chatgroup')
router.register(r'messages', MessageViewSet, basename='message')

urlpatterns = [
    path('', include(router.urls)),
]
