import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for GCRM One using the iOS configuration from GoogleService-Info.plist.
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
        return ios;
      default:
        return ios;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAjuFTXDxZ_dOu7DyyPndVxNdWOJqB8Beo',
    appId: '1:471565987174:ios:0dc445a6d9f929dfc8eca7',
    messagingSenderId: '471565987174',
    projectId: 'gcrm-one',
    storageBucket: 'gcrm-one.firebasestorage.app',
    iosBundleId: 'com.gcrmone.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjuFTXDxZ_dOu7DyyPndVxNdWOJqB8Beo',
    appId: '1:471565987174:ios:0dc445a6d9f929dfc8eca7',
    messagingSenderId: '471565987174',
    projectId: 'gcrm-one',
    storageBucket: 'gcrm-one.firebasestorage.app',
    iosBundleId: 'com.gcrmone.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAjuFTXDxZ_dOu7DyyPndVxNdWOJqB8Beo',
    appId: '1:471565987174:ios:0dc445a6d9f929dfc8eca7',
    messagingSenderId: '471565987174',
    projectId: 'gcrm-one',
    storageBucket: 'gcrm-one.firebasestorage.app',
  );
}
