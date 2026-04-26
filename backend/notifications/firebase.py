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


def _sanitize_data(data):
    """FCM data payload values MUST all be strings. Sanitize to prevent SDK errors."""
    if not data:
        return {}
    return {str(k): ('' if v is None else str(v)) for k, v in data.items()}


def _build_apns_config():
    # iOS/APNs delivery tuning. Helps foreground/background reliability on iOS.
    # NOTE: Do NOT pass custom_data here — data is already sent via Message.data.
    # Duplicating it in APNSConfig.custom_data can exceed Apple's 4KB payload limit.
    return messaging.APNSConfig(
        headers={
            'apns-priority': '10',
            'apns-push-type': 'alert',
        },
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                content_available=True,
                mutable_content=True,
                sound='default',
            ),
        ),
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


def _tokens_for_user_ids(user_ids):
    from users.models import UserFcmDevice
    if not user_ids:
        return []
    return list(
        UserFcmDevice.objects.filter(user_id__in=user_ids).values_list('token', flat=True)
    )


def _all_fcm_tokens():
    from users.models import UserFcmDevice
    return list(UserFcmDevice.objects.values_list('token', flat=True))


def _delete_invalid_tokens(failed_tokens):
    if not failed_tokens:
        return
    from users.models import UserFcmDevice
    deleted, _ = UserFcmDevice.objects.filter(token__in=failed_tokens).delete()
    logger.info('Removed %d invalid FCM device row(s)', deleted)


def send_fcm_to_user(user_id, title, body, data=None):
    """Send FCM push notification to a single user by user_id (bütün qeydiyyatlı cihazlara)."""
    tokens = _dedupe_tokens(_tokens_for_user_ids([user_id]))
    if not tokens:
        return
    _send_fcm_multicast(tokens, title, body, data)


def send_fcm_to_users(user_ids, title, body, data=None):
    """Send FCM push notification to multiple users."""
    tokens = _dedupe_tokens(_tokens_for_user_ids(user_ids))
    
    if not tokens:
        return
    
    _send_fcm_multicast(tokens, title, body, data)


def send_fcm_to_all(title, body, data=None):
    """Send FCM push notification to all registered device tokens."""
    tokens = _dedupe_tokens(_all_fcm_tokens())
    
    if not tokens:
        return
    
    _send_fcm_multicast(tokens, title, body, data)


def _send_fcm_multicast(tokens, title, body, data=None):
    """Send an FCM message to multiple device tokens efficiently."""
    app = _get_firebase_app()
    if app is None:
        return

    safe_data = _sanitize_data(data)

    # FCM limits multicast to 500 tokens per message
    for i in range(0, len(tokens), 500):
        batch_tokens = tokens[i:i + 500]
        
        android_config = messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                title=title,
                body=body,
                tag=safe_data.get('tag') or None,
                channel_id='digitask_notifications',
            ),
        )
        apns_config = _build_apns_config()
        
        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            android=android_config,
            apns=apns_config,
            data=safe_data,
            tokens=batch_tokens,
        )
        
        try:
            response = messaging.send_each_for_multicast(message)
            if response.failure_count > 0:
                responses = response.responses
                failed_tokens = []
                for idx, resp in enumerate(responses):
                    if not resp.success:
                        if isinstance(resp.exception, messaging.UnregisteredError):
                            failed_tokens.append(batch_tokens[idx])
                        else:
                            logger.warning('FCM send failed for token %d: %s', idx, resp.exception)
                
                if failed_tokens:
                    _delete_invalid_tokens(failed_tokens)
        except Exception as e:
            logger.error('FCM multicast send error: %s', e)


def _send_fcm_message(token, title, body, data=None):
    """Send a single FCM message to a device token."""
    app = _get_firebase_app()
    if app is None:
        return
    
    safe_data = _sanitize_data(data)
    
    android_config = messaging.AndroidConfig(
        priority='high',
        notification=messaging.AndroidNotification(
            title=title,
            body=body,
            tag=safe_data.get('tag') or None,
            channel_id='digitask_notifications',
        ),
    )
    apns_config = _build_apns_config()
    
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        android=android_config,
        apns=apns_config,
        data=safe_data,
        token=token,
    )
    
    try:
        messaging.send(message)
    except messaging.UnregisteredError:
        _delete_invalid_tokens([token])
    except Exception as e:
        logger.error('FCM send error: %s', e)
