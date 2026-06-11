/// Single source of truth for the app's identity.
///
/// The working title is "REACH". To rebrand the final app, change the
/// constants in this file. Note that two of these values are *mirrored* in
/// native build files that cannot read Dart at build time — when you change
/// [kBundleId] or [kAppName] you must also update the native mirrors listed
/// below (this is the only out-of-Dart duplication, and it is documented in
/// the README under "Renaming / rebranding"):
///
///   * Android applicationId / package
///       - android/app/build.gradle.kts          (applicationId, namespace)
///       - android/app/src/main/.../MainActivity  (kotlin package dir)
///   * Android display name
///       - android/app/src/main/AndroidManifest.xml  (android:label)
///   * iOS bundle identifier
///       - ios/Runner.xcodeproj  (PRODUCT_BUNDLE_IDENTIFIER, 3 build configs)
///   * iOS display name
///       - ios/Runner/Info.plist  (CFBundleDisplayName / CFBundleName)
///
/// Everything *inside* the Dart/Flutter layer (window title, store config,
/// share text, etc.) reads from here, so renaming is a one-line change on the
/// Dart side plus the documented native mirrors.
library;

/// User-facing application name. Working title; swap here to rebrand.
const String kAppName = 'REACH';

/// One-line tagline used on the home screen and share text.
const String kAppTagline = 'a calm number puzzle';

/// Marketing version shown in Settings. Keep in step with `pubspec.yaml`'s
/// `version:` and the matching git tag (e.g. `v1.1`).
const String kAppVersion = '1.9';

/// Reverse-DNS bundle / package identifier used by the stores. This is the
/// REAL, PERMANENT id (org segment = the developer handle, so it survives any
/// game rename and groups future apps) — it must NOT change after the first
/// store publish. Mirrored in the native files documented above (iOS project,
/// Android gradle namespace/applicationId, and the Kotlin package directory),
/// and it namespaces the IAP product ids in `iap_config.dart`. Use this exact
/// id when registering the iOS + Android apps in Firebase.
const String kBundleId = 'com.utkuyuksel.reach';

/// Privacy policy URL shown in Settings (required by the stores for apps with
/// ads/IAP). TODO: replace with the real hosted policy URL before shipping.
const String kPrivacyPolicyUrl = 'https://example.com/reach/privacy';

/// Call-to-action link appended to the viral Daily share, so anyone who sees a
/// shared result can find the game (Wordle-style organic growth).
///
/// Intentionally EMPTY for now: there's no landing page / store listing yet, so
/// the share omits the URL entirely rather than ship a dead link. When a
/// landing page or store link exists, set it here and it reappears in the
/// share text and on the result card automatically. A single smart link that
/// routes to the right store is ideal.
const String kShareUrl = '';
