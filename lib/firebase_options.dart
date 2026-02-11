// Firebase configuration for UNIMAS SmartBus
// Generated from google-services.json

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCC7XHbA6k-jLiOq8FBOyB4EWoZ7ALM7EY',
    appId: '1:742597414742:android:22980fcf99922d322fd0f7',
    messagingSenderId: '742597414742',
    projectId: 'unimas-smartbus',
    storageBucket: 'unimas-smartbus.firebasestorage.app',
    databaseURL: 'https://unimas-smartbus-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCC7XHbA6k-jLiOq8FBOyB4EWoZ7ALM7EY',
    appId: 'TODO_IOS_APP_ID', // Add from Firebase Console iOS app
    messagingSenderId: '742597414742',
    projectId: 'unimas-smartbus',
    storageBucket: 'unimas-smartbus.firebasestorage.app',
    databaseURL: 'https://unimas-smartbus-default-rtdb.asia-southeast1.firebasedatabase.app',
    iosBundleId: 'com.example.unimasSmartbus', // Update if different
  );

  static const FirebaseOptions currentPlatform = android;
}
