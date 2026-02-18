import json
from .models import AuditLog

class AuditLoggingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Process request
        response = self.get_response(request)
        
        # Log after response to ensure we capture the final state/user
        # Only log modification requests
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

            # Extract User
            user = request.user if request.user.is_authenticated else None

            # Extract Payload
            payload = None
            try:
                # Try to get body without triggering RawPostDataException
                # If DRF has already read it, it might be in _body
                if hasattr(request, '_body'):
                    body = request._body
                else:
                    body = request.body
                
                if body:
                    payload = json.loads(body.decode('utf-8'))
            except Exception:
                # If we can't read the body (e.g. file upload or already read stream), just skip payload
                pass
            
            # Create Log
            # We use a try-except block to avoid breaking the response if logging fails
            try:
                AuditLog.objects.create(
                    user=user,
                    action=request.method,  # Mapped to method for now
                    method=request.method,
                    path=request.path,
                    ip_address=ip,
                    payload=payload
                )
            except Exception as e:
                print(f"Failed to create audit log: {e}")

        return response
