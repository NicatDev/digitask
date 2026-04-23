from django.db.models.signals import pre_save, post_save, post_delete
from django.dispatch import receiver
from django.apps import apps
from django.forms.models import model_to_dict
from .models import AuditLog
from .utils import get_current_user, get_current_ip
from django.conf import settings
import json
from django.core.serializers.json import DjangoJSONEncoder

EXCLUDED_MODELS = [
    # Django internals
    'AuditLog', 'Session', 'LogEntry', 'Permission', 'ContentType',
    # Location / tracking — changes every few seconds per user, floods the log
    'UserLocation', 'LocationHistory',
    # Chat — messages, read statuses, memberships generate massive volume
    'Message', 'MessageReadStatus', 'GroupMembership',
    # Notifications — auto-generated, not user actions
    'Notification',
]

def get_model_name(instance):
    return instance._meta.model_name

def get_changes(old_state, new_state):
    changes = {}
    for key, value in new_state.items():
        if key not in old_state:
            continue
        if old_state[key] != value:
            changes[key] = {'old': old_state[key], 'new': value}
    return changes

def serialize_instance(instance):
    # Helper to serialize fields safely
    # We use model_to_dict but might need to handle FileFields or Dates manually
    try:
        data = model_to_dict(instance)
        # Convert non-serializable objects (like dates) to strings if needed
        # Or allow JSONField to handle it via DjangoJSONEncoder
        return json.loads(json.dumps(data, cls=DjangoJSONEncoder))
    except:
        return {}

# 1. PRE-SAVE: Capture old state
def audit_pre_save(sender, instance, **kwargs):
    if sender.__name__ in EXCLUDED_MODELS:
        return
    
    if instance.pk:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            instance._old_state = serialize_instance(old_instance)
        except sender.DoesNotExist:
            instance._old_state = {}
    else:
        instance._old_state = {}

# 2. POST-SAVE: Log Create/Update
def audit_post_save(sender, instance, created, **kwargs):
    if sender.__name__ in EXCLUDED_MODELS:
        return

    user = get_current_user()
    ip = get_current_ip()
    
    if created:
        action = 'CREATE'
        changes = serialize_instance(instance) # For create, everything is new
    else:
        action = 'UPDATE'
        old_state = getattr(instance, '_old_state', {})
        new_state = serialize_instance(instance)
        changes = get_changes(old_state, new_state)
        
        # If no changes detected (e.g. save called but nothing changed), skip
        if not changes:
            return

    try:
        AuditLog.objects.create(
            user=user,
            action=action,
            resource_type=sender.__name__,
            resource_id=str(instance.pk),
            ip_address=ip,
            changes=changes
        )
    except Exception as e:
        print(f"Error creating audit log: {e}")

# 3. POST-DELETE: Log Delete
def audit_post_delete(sender, instance, **kwargs):
    if sender.__name__ in EXCLUDED_MODELS:
        return

    user = get_current_user()
    ip = get_current_ip()
    changes = serialize_instance(instance)

    try:
        AuditLog.objects.create(
            user=user,
            action='DELETE',
            resource_type=sender.__name__,
            resource_id=str(instance.pk),
            ip_address=ip,
            changes=changes
        )
    except Exception as e:
        print(f"Error creating audit log: {e}")

