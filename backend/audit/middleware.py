from rest_framework_simplejwt.authentication import JWTAuthentication
from .utils import set_current_user

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

        # Set current user in thread local
        user = request.user if request.user.is_authenticated else None
        set_current_user(user)

        # Process request
        response = self.get_response(request)
        
        # We will rely on SIGNALS (post_save/post_delete) for data changes.
        # However, we can still log generic requests here if needed, or remove request logging
        # to focus purely on DB changes. The user asked for "detailed logs about model updates".
        # So we keep this for "Access Logs" maybe? 
        # Actually, let's keep it but skip "READ" operations to reduce noise, consistent with previous logic.
        
        # Log modification requests (HTTP level)
        if request.method in ['POST', 'PUT', 'PATCH', 'DELETE']:
             # Exclude specific paths
            if any(path in request.path for path in ['/admin/', '/static/', '/media/', '/auth/', '/token/']):
                return response
            
            # Extract IP
            x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
            if x_forwarded_for:
                ip = x_forwarded_for.split(',')[0]
            else:
                ip = request.META.get('REMOTE_ADDR')

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

