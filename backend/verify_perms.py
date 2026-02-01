
import os
import django
import sys

sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from users.models import User

for u in User.objects.all().order_by('id'):
    print(f"\n=== USER: {u.username} (ID: {u.id}) ===")
    print(f"DTO Fields:")
    if u.role:
        print(f"  ROLE: {u.role.name}")
        print(f"  role.is_admin: {u.role.is_admin}")
        print(f"  role.is_super_admin: {u.role.is_super_admin}")
        print(f"  role.is_task_writer: {u.role.is_task_writer}")
        print(f"  role.is_task_reader: {u.role.is_task_reader}")
    else:
        print("  NO ROLE ASSIGNED")
        
    print(f"Django Built-ins:")
    print(f"  is_superuser: {u.is_superuser}")
    print(f"  is_staff: {u.is_staff}")
