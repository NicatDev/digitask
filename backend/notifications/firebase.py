import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
import os
import logging

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
_firebase_app = None


def _dedupe_tokens(tokens):
    # Preserve order while dropping duplicate device tokens.
    return list(dict.fromkeys(tokens))


def _build_apns_config(data=None):
    # iOS/APNs delivery tuning. Helps foreground/background reliability on iOS.
    return messaging.APNSConfig(
        headers={
            'apns-priority': '10',
            'apns-push-type': 'alert',
        },
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                content_available=True,
                sound='default',
            ),
        ),
        custom_data=data or {},
    )

def _get_firebase_app():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    
    cred_path = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
    if not os.path.exists(cred_path):
        logger.warning('Firebase service account JSON not found at %s. FCM will not work.', cred_path)
        return None
    
    try:
        cred = credentials.Certificate(cred_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        return _firebase_app
    except Exception as e:
        logger.error('Failed to initialize Firebase: %s', e)
        return None


def send_fcm_to_user(user_id, title, body, data=None):
    """Send FCM push notification to a single user by user_id."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    try:
        user = User.objects.get(id=user_id)
        if not user.fcm_token:
            return
        _send_fcm_message(user.fcm_token, title, body, data)
    except User.DoesNotExist:
        pass


def send_fcm_to_users(user_ids, title, body, data=None):
    """Send FCM push notification to multiple users."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    tokens = list(
        User.objects.filter(id__in=user_ids, fcm_token__isnull=False)
        .exclude(fcm_token='')
        .values_list('fcm_token', flat=True)
    )
    tokens = _dedupe_tokens(tokens)
    
    if not tokens:
        return
    
    _send_fcm_multicast(tokens, title, body, data)


def send_fcm_to_all(title, body, data=None):
    """Send FCM push notification to all users with FCM tokens."""
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    tokens = list(
        User.objects.filter(fcm_token__isnull=False)
        .exclude(fcm_token='')
        .values_list('fcm_token', flat=True)
    )
    tokens = _dedupe_tokens(tokens)
    
    if not tokens:
        return
    
    _send_fcm_multicast(tokens, title, body, data)


def _send_fcm_multicast(tokens, title, body, data=None):
    """Send an FCM message to multiple device tokens efficiently."""
    app = _get_firebase_app()
    if app is None:
        return

    # FCM limits multicast to 500 tokens per message
    for i in range(0, len(tokens), 500):
        batch_tokens = tokens[i:i + 500]
        
        android_config = messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                tag=data.get('tag') if data else None,
                channel_id='digitask_notifications',
            ),
        )
        apns_config = _build_apns_config(data=data)
        
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            android=android_config,
            apns=apns_config,
            data=data or {},
            tokens=batch_tokens,
        )
        
        try:
            response = messaging.send_each_for_multicast(message)
            if response.failure_count > 0:
                responses = response.responses
                failed_tokens = []
                for idx, resp in enumerate(responses):
                    if not resp.success and isinstance(resp.exception, messaging.UnregisteredError):
                        failed_tokens.append(batch_tokens[idx])
                
                # Token is invalid, remove it
                if failed_tokens:
                    from django.contrib.auth import get_user_model
                    User = get_user_model()
                    User.objects.filter(fcm_token__in=failed_tokens).update(fcm_token=None)
                    logger.info('Removed %d invalid FCM tokens', len(failed_tokens))
        except Exception as e:
            logger.error('FCM multicast send error: %s', e)


def _send_fcm_message(token, title, body, data=None):
    """Send a single FCM message to a device token."""
    app = _get_firebase_app()
    if app is None:
        return
    
    android_config = messaging.AndroidConfig(
        priority='high',
        notification=messaging.AndroidNotification(
            title=title,
            body=body,
            tag=data.get('tag') if data else None,
            channel_id='digitask_notifications',
        ),
    )
    apns_config = _build_apns_config(data=data)
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        android=android_config,
        apns=apns_config,
        data=data or {},
        token=token,
    )
    
    try:
        messaging.send(message)
    except messaging.UnregisteredError:
        # Token is invalid, remove it
        from django.contrib.auth import get_user_model
        User = get_user_model()
        User.objects.filter(fcm_token=token).update(fcm_token=None)
        logger.info('Removed invalid FCM token: %s...', token[:20])
    except Exception as e:
        logger.error('FCM send error: %s', e)
