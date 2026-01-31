from .account import UserViewSet, RoleViewSet
from .common import RegionViewSet, GroupViewSet
 
# Wait, I deleted views.py before, so LoginView might be gone or I need to restore it/move it.
# The user asked for JWT token auth. I used TokenObtainPairView in urls.py.
# So I might not need a custom LoginView unless for legacy validaton.
# I will check urls.py content again.
