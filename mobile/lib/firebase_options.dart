import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android config from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAq7zMKXVECu5bvMQzru4_nXeU1AiT77tM',
    appId: '1:656216418148:android:a8c3d56423a18114c6fc71',
    messagingSenderId: '656216418148',
    projectId: 'digigroup-11ad6',
    storageBucket: 'digigroup-11ad6.firebasestorage.app',
  );

  // Web config — Firebase Console-dan götürülməlidir
  // Firebase Console → Project Settings → General → Web apps → Config
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAq7zMKXVECu5bvMQzru4_nXeU1AiT77tM',
    appId: '1:656216418148:web:YOUR_WEB_APP_ID',  // ← Firebase Console-dan dəyişin
    messagingSenderId: '656216418148',
    projectId: 'digigroup-11ad6',
    storageBucket: 'digigroup-11ad6.firebasestorage.app',
    authDomain: 'digigroup-11ad6.firebaseapp.com',
  );

  // iOS config — əgər lazımdırsa əlavə edin
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAq7zMKXVECu5bvMQzru4_nXeU1AiT77tM',
    appId: '1:656216418148:ios:YOUR_IOS_APP_ID',  // ← Firebase Console-dan dəyişin
    messagingSenderId: '656216418148',
    projectId: 'digigroup-11ad6',
    storageBucket: 'digigroup-11ad6.firebasestorage.app',
    iosBundleId: 'com.digigroup.ios',
  );
}
