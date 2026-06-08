/// Ads behind an interface so the game runs fully without an AdMob account
/// (via [DevAdService]) and so ad logic can be mocked in tests.
///
/// Monetization never gates progress: rewarded ads only *grant* an optional
/// hint, and interstitials appear conservatively in Zen (never in Daily).
abstract class AdService {
  Future<void> init();

  /// Show a rewarded ad. Resolves `true` if the user earned the reward
  /// (i.e. a hint should be granted), `false` if it was dismissed or failed.
  Future<bool> showRewardedAd();

  /// Show an interstitial if one is ready. Safe to call frequently; the caller
  /// decides cadence. Never call this in the Daily Challenge.
  Future<void> showInterstitial();

  void dispose();
}

/// No-op implementation for development and tests. Rewarded ads "succeed"
/// instantly (so hints work without an ad network), interstitials do nothing.
class DevAdService implements AdService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewardedAd() async => true;

  @override
  Future<void> showInterstitial() async {}

  @override
  void dispose() {}
}
