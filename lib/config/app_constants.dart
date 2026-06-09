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
const String kAppVersion = '1.3';

/// Reverse-DNS bundle / package identifier used by the stores.
///
/// Placeholder for the working title. Replace with the real identifier before
/// shipping, and mirror it in the native files documented above.
const String kBundleId = 'com.reach.reach';

/// Privacy policy URL shown in Settings (required by the stores for apps with
/// ads/IAP). TODO: replace with the real hosted policy URL before shipping.
const String kPrivacyPolicyUrl = 'https://example.com/reach/privacy';

/// Call-to-action link appended to the viral Daily share, so anyone who sees a
/// shared result can find the game (Wordle-style organic growth).
/// TODO: replace with the real App Store / Play Store / landing URL before
/// shipping (a single smart link that routes to the right store is ideal).
const String kShareUrl = 'https://reach.game';
