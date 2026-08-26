import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web in this project.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android and iOS in this project.',
        );
    }
  }

  // Values derived from the native Firebase config files:
  // - Android: `android/app/google-services.json`
  // - iOS: `ios/Runner/GoogleService-Info.plist`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADxbsYwEiagCqMaLYTtc-z3MGZqSC0w3w',
    appId: '1:492094390523:android:1d310373ae69b437fcb05e',
    messagingSenderId: '492094390523',
    projectId: 'bsmart-5116a',
    storageBucket: 'bsmart-5116a.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCbX6V-la0HW4S_xBbf0IuOVusEeGBGMrE',
    appId: '1:652664354990:ios:563d6fa6b969cc9379553f',
    messagingSenderId: '652664354990',
    projectId: 'bsmart-ios',
    storageBucket: 'bsmart-ios.firebasestorage.app',
    iosBundleId: 'com.ruvees.bsmart.ios',
  );
}
