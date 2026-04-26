/* eslint-disable no-undef */
// Arxa plan push — Firebase compat build (versiya npm firebase ilə uyğun saxlayın).
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyBeYelvMbucRyROknuTx6_ov3ZLO2fP2hU',
    authDomain: 'digigroup-11ad6.firebaseapp.com',
    projectId: 'digigroup-11ad6',
    storageBucket: 'digigroup-11ad6.firebasestorage.app',
    messagingSenderId: '656216418148',
    appId: '1:656216418148:web:6c3c470ebc2292d0c6fc71',
    measurementId: 'G-210MWM4MR5',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    const title = payload.notification?.title || 'Digitask';
    const options = {
        body: payload.notification?.body || '',
        data: payload.data || {},
    };
    self.registration.showNotification(title, options);
});
