// lib/firebase_options.dart
// Конфигурация Firebase для Flutter

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDPg742aNStByzTnjl-MrRlpJmppSZ4jzU',
    appId: '1:313734310210:web:a82d4c8080ef15e45e40db',
    messagingSenderId: '313734310210',
    projectId: 'soobshio',
    authDomain: 'soobshio.firebaseapp.com',
    storageBucket: 'soobshio.appspot.com',
    measurementId: 'G-XXXXX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDPg742aNStByzTnjl-MrRlpJmppSZ4jzU',
    appId: '1:313734310210:android:a82d4c8080ef15e45e40db',
    messagingSenderId: '313734310210',
    projectId: 'soobshio',
    storageBucket: 'soobshio.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDPg742aNStByzTnjl-MrRlpJmppSZ4jzU',
    appId: '1:313734310210:ios:a82d4c8080ef15e45e40db',
    messagingSenderId: '313734310210',
    projectId: 'soobshio',
    storageBucket: 'soobshio.appspot.com',
    iosBundleId: 'com.soobshio.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDPg742aNStByzTnjl-MrRlpJmppSZ4jzU',
    appId: '1:313734310210:ios:a82d4c8080ef15e45e40db',
    messagingSenderId: '313734310210',
    projectId: 'soobshio',
    storageBucket: 'soobshio.appspot.com',
    iosBundleId: 'com.soobshio.app',
  );
}
