from django.contrib.auth.models import AnonymousUser
from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from rest_framework_simplejwt.tokens import AccessToken
from django.contrib.auth import get_user_model
from urllib.parse import parse_qs

User = get_user_model()

@database_sync_to_async
def get_user(token_key):
    try:
        access_token = AccessToken(token_key)
        user_id = access_token.payload['user_id']
        return User.objects.get(id=user_id)
    except Exception as e:
        return AnonymousUser()

class JwtAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        # Parse query string for token
        query_string = parse_qs(scope["query_string"].decode())
        token = query_string.get("token")
        
        if token:
            scope['user'] = await get_user(token[0])
        else:
            scope['user'] = AnonymousUser()
        
        return await super().__call__(scope, receive, send)
