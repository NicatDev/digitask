/**
 * Firebase Web config (apiKey və s. brauzerdə “public” sayılır).
 * VAPID: Firebase Console → Project settings → Cloud Messaging → Web Push certificates.
 * İstəyə bağlı: VITE_FIREBASE_VAPID_KEY ilə əvəz etmək olar.
 */
const FALLBACK_VAPID_KEY =
    'BCRLjljYFGuG3qRTkTECdsYXVAHUmk55clU643W15S39Npu-rmIUxXXsWG5tALwEp630MNUPk-NqVmZVO9hc8fA';

const FALLBACK_WEB_CONFIG = {
    apiKey: 'AIzaSyBeYelvMbucRyROknuTx6_ov3ZLO2fP2hU',
    authDomain: 'digigroup-11ad6.firebaseapp.com',
    projectId: 'digigroup-11ad6',
    storageBucket: 'digigroup-11ad6.firebasestorage.app',
    messagingSenderId: '656216418148',
    appId: '1:656216418148:web:6c3c470ebc2292d0c6fc71',
    measurementId: 'G-210MWM4MR5',
};

export function getFirebaseWebConfig() {
    const e = import.meta.env;
    return {
        apiKey: e.VITE_FIREBASE_API_KEY || FALLBACK_WEB_CONFIG.apiKey,
        authDomain: e.VITE_FIREBASE_AUTH_DOMAIN || FALLBACK_WEB_CONFIG.authDomain,
        projectId: e.VITE_FIREBASE_PROJECT_ID || FALLBACK_WEB_CONFIG.projectId,
        storageBucket: e.VITE_FIREBASE_STORAGE_BUCKET || FALLBACK_WEB_CONFIG.storageBucket,
        messagingSenderId: e.VITE_FIREBASE_MESSAGING_SENDER_ID || FALLBACK_WEB_CONFIG.messagingSenderId,
        appId: e.VITE_FIREBASE_APP_ID || FALLBACK_WEB_CONFIG.appId,
        measurementId: e.VITE_FIREBASE_MEASUREMENT_ID || FALLBACK_WEB_CONFIG.measurementId,
    };
}

/** Web Push (FCM) üçün — Firebase Console-da yaradılan key pair */
export function getFirebaseVapidKey() {
    const fromEnv = (import.meta.env.VITE_FIREBASE_VAPID_KEY || '').trim();
    return fromEnv || FALLBACK_VAPID_KEY;
}
