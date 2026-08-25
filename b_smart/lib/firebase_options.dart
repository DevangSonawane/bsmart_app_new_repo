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
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android in this project.',
        );
    }
  }

  // Values derived from `android/app/google-services.json`.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADxbsYwEiagCqMaLYTtc-z3MGZqSC0w3w',
    appId: '1:492094390523:android:1d310373ae69b437fcb05e',
    messagingSenderId: '492094390523',
    projectId: 'bsmart-5116a',
    storageBucket: 'bsmart-5116a.firebasestorage.app',
  );
}
