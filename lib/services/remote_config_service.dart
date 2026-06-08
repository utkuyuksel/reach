/// Tunable game parameters in one place, served behind an interface so they can
/// be adjusted *after launch without a new build* (the seam for a real remote
/// config backend like Firebase Remote Config). The local implementation ships
/// sensible defaults; a future backend impl would fetch + override them.
///
/// Keeping the economy + difficulty knobs here (not hard-coded) is what lets us
/// tune generosity/cadence live once analytics show real player behaviour.
class GameConfig {
  // --- Coin economy ---
  final int startingCoins;
  final int hintCost;
  final int coinsPerClear;
  final int coinsPerRewardedAd;
  final int dailyClearBonus;

  // --- Ads ---
  /// Show an interstitial every N Zen board clears (never in Daily/Premium).
  final int interstitialEveryNClears;

  // --- Stars (efficiency; hints do NOT reduce stars — see "clean" badge) ---
  /// Wrong/bounced traces allowed for 2 stars (0 wrong ⇒ 3 stars; more ⇒ 1).
  final int starTwoStarMaxWrong;

  const GameConfig({
    this.startingCoins = 60,
    this.hintCost = 20,
    this.coinsPerClear = 12,
    this.coinsPerRewardedAd = 25,
    this.dailyClearBonus = 30,
    this.interstitialEveryNClears = 7,
    this.starTwoStarMaxWrong = 2,
  });

  const GameConfig.defaults() : this();

  /// Stars (1–3) for a board cleared with [wrongTraces] rejected attempts.
  int starsForWrong(int wrongTraces) {
    if (wrongTraces <= 0) return 3;
    if (wrongTraces <= starTwoStarMaxWrong) return 2;
    return 1;
  }
}

abstract class RemoteConfigService {
  Future<void> init();
  GameConfig get config;
}

/// Default implementation: ships baked-in defaults. Replace/augment with a real
/// backend later (fetch values, map to [GameConfig]) without touching callers.
class LocalRemoteConfigService implements RemoteConfigService {
  @override
  Future<void> init() async {}

  @override
  GameConfig get config => const GameConfig.defaults();
}
