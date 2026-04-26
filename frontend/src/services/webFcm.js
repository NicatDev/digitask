import { initializeApp, getApps } from 'firebase/app';
import { getMessaging, getToken, onMessage, isSupported } from 'firebase/messaging';
import { getFirebaseWebConfig, getFirebaseVapidKey } from '../config/firebase';
import { registerFcmToken } from '../axios/api/account';

let messagingSingleton = null;

function getOrInitApp() {
    const config = getFirebaseWebConfig();
    if (!config.apiKey || !config.appId) {
        return null;
    }
    if (getApps().length > 0) {
        return getApps()[0];
    }
    return initializeApp(config);
}

/**
 * Brauzer FCM tokenini alır, backend-ə yazır (`platform: web`), foreground mesajları göstərir.
 */
export async function initWebFcm() {
    if (typeof window === 'undefined') return null;

    const supported = await isSupported();
    if (!supported) {
        console.warn('[FCM Web] Bu brauzerdə Firebase Messaging dəstəklənmir');
        return null;
    }

    const vapidKey = getFirebaseVapidKey();
    if (!vapidKey) {
        console.warn(
            '[FCM Web] VITE_FIREBASE_VAPID_KEY yoxdur. Firebase Console → Cloud Messaging → Web Push certificates üzrə açar əlavə edin.'
        );
        return null;
    }

    const app = getOrInitApp();
    if (!app) {
        console.warn('[FCM Web] Firebase konfiqurasiyası natamamdır');
        return null;
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
        console.warn('[FCM Web] Bildiriş icazəsi verilmədi');
        return null;
    }

    messagingSingleton = getMessaging(app);

    const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
    await navigator.serviceWorker.ready;

    const token = await getToken(messagingSingleton, {
        vapidKey,
        serviceWorkerRegistration: registration,
    });

    if (!token) {
        console.warn('[FCM Web] Token alınmadı');
        return null;
    }

    try {
        await registerFcmToken(token, 'web');
    } catch (e) {
        console.error('[FCM Web] Token backend-ə yazılmadı', e);
    }

    onMessage(messagingSingleton, (payload) => {
        const title = payload.notification?.title || 'Digitask';
        const body = payload.notification?.body || '';
        if (document.visibilityState === 'visible' && Notification.permission === 'granted') {
            // Ön planda: sistem tray bildirişi (WS toast ilə üst-üstə düşə bilər — ehtiyac olsa sonra incələyin).
            try {
                new Notification(title, { body, tag: payload.data?.tag || 'digitask-fcm' });
            } catch (err) {
                console.warn('[FCM Web] Notification göstərilmədi', err);
            }
        }
    });

    return token;
}
