import json
from rest_framework_simplejwt.authentication import JWTAuthentication
from .utils import set_current_user, set_current_ip
from .models import AuditLog

class AuditLoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Attempt to authenticate via JWT if not already authenticated
        if not request.user.is_authenticated:
            try:
                jwt_auth = JWTAuthentication()
                auth_result = jwt_auth.authenticate(request)
                if auth_result:
                    user, token = auth_result
                    request.user = user
            except Exception:
                pass

        # Try to extract IP
        ip = None
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR')

        # Set current user and IP in thread local
        user = getattr(request, 'user', None)
        if user and not user.is_authenticated:
            user = None
        set_current_user(user)
        set_current_ip(ip)

        # Process request
        response = self.get_response(request)
        
        # We will rely on SIGNALS (post_save/post_delete) for data changes.
        # However, we can still log generic requests here if needed, or remove request logging
        # to focus purely on DB changes. The user asked for "detailed logs about model updates".
        # So we keep this for "Access Logs" maybe? 
        # Actually, let's keep it but skip "READ" operations to reduce noise, consistent with previous logic.
        
        # Log modification requests (HTTP level)
        if request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
             # Exclude specific paths that generate too much noise
            excluded_paths = [
                '/admin/', '/static/', '/media/', '/auth/', '/token/',
                # High-frequency endpoints — location, tracking, chat, notifications
                '/location/', '/tracking/',
                '/chat/messages/mark-read/',
                '/fcm-token/',
                '/notifications/read/', '/notifications/read-all/',
            ]
            if any(path in request.path for path in excluded_paths):
                return response
            # IP is already extracted at the start of request

            # Extract Payload
            payload = None
            try:
                if hasattr(request, '_body'):
                    body = request._body
                else:
                    body = request.body
                
                if body:
                    payload = json.loads(body.decode('utf-8'))
            except Exception:
                pass
            
            # Create HTTP Access Log (Optional, but good for tracking WHO did URL call)
            # This complements the DB signal log (WHICH field changed).
            try:
                AuditLog.objects.create(
                    user=user,
                    action=request.method,
                    method=request.method,
                    path=request.path,
                    ip_address=ip,
                    payload=payload,
                    resource_type='HTTP Request', # Distinguish from Model Changes
                    resource_id=None,
                    changes=None
                )
            except Exception:
                pass

        return response

