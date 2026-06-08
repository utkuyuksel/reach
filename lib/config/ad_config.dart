import 'dart:io' show Platform;

/// Ad configuration in ONE place.
///
/// These are Google's official **test** ad unit IDs — they always return a
/// test ad and are safe to ship during development. They will NOT earn
/// revenue and MUST be replaced before release.
///
/// TODO: replace every value below with your real AdMob ad unit IDs, and set
///       the real AdMob App ID in the native manifests (see README →
///       "Ads & IAP setup"):
///         * Android: android/app/src/main/AndroidManifest.xml — the
///           `com.google.android.gms.ads.APPLICATION_ID` meta-data tag.
///         * iOS: ios/Runner/Info.plist — the `GADApplicationIdentifier` key.
class AdConfig {
  /// Conservative interstitial cadence: show one every N Zen solves.
  /// Never shown in the Daily Challenge.
  static const int interstitialEveryNZenSolves = 7;

  // Google test ad unit IDs.
  static const String _androidRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static const String _androidInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  static String get rewardedAdUnitId =>
      Platform.isIOS ? _iosRewarded : _androidRewarded;

  static String get interstitialAdUnitId =>
      Platform.isIOS ? _iosInterstitial : _androidInterstitial;
}
