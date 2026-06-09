// Firebase init options, generated from the project's GoogleService-Info.plist
// (iOS) and google-services.json (Android) for project `reach-37923`. Using
// explicit options means `Firebase.initializeApp(options: ...)` works purely
// from Dart — no dependency on the iOS plist being in the Xcode target or the
// Android google-services Gradle plugin.
//
// These values are CLIENT identifiers (not secrets); Firebase access is
// governed by security rules / quotas, so they are safe to commit (this is how
// the FlutterFire CLI ships firebase_options.dart too).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Firebase.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDEEwqIy1mR964WD7roqi4VcQwIkaYSqfo',
    appId: '1:1083204361538:android:a30c871dd79a43b0febcdb',
    messagingSenderId: '1083204361538',
    projectId: 'reach-37923',
    storageBucket: 'reach-37923.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDUMB1-7GHsh-YwPyoLfuDyAMAr-5lxitg',
    appId: '1:1083204361538:ios:9bebedeab325c17ffebcdb',
    messagingSenderId: '1083204361538',
    projectId: 'reach-37923',
    storageBucket: 'reach-37923.firebasestorage.app',
    iosBundleId: 'com.utkuyuksel.reach',
  );
}
