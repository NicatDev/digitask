from django.apps import AppConfig


class AuditConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'audit'

    def ready(self):
        from django.db.models.signals import pre_save, post_save, post_delete
        from django.apps import apps
        from .signals import audit_pre_save, audit_post_save, audit_post_delete, EXCLUDED_MODELS
        
        for model in apps.get_models():
            # Exclude models if needed (signals.py handles exclusion too, but good to double check or optimize)
            if model.__name__ in EXCLUDED_MODELS:
                continue
            
            # Use dispatch_uid to prevent duplicate signals
            uid_pre = f"audit_pre_save_{model._meta.label}"
            uid_post = f"audit_post_save_{model._meta.label}"
            uid_del = f"audit_post_del_{model._meta.label}"

            pre_save.connect(audit_pre_save, sender=model, dispatch_uid=uid_pre)
            post_save.connect(audit_post_save, sender=model, dispatch_uid=uid_post)
            post_delete.connect(audit_post_delete, sender=model, dispatch_uid=uid_del)
