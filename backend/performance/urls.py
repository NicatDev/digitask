from django.urls import path
from .views import UserPerformanceView

urlpatterns = [
    path('user-stats/', UserPerformanceView.as_view(), name='user-stats'),
]
