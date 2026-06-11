/// Tunable game parameters in one place, served behind an interface so they can
/// be adjusted *after launch without a new build* (the seam for a real remote
/// config backend like Firebase Remote Config). The local implementation ships
/// sensible defaults; a future backend impl would fetch + override them.
///
/// Keeping the economy + difficulty knobs here (not hard-coded) is what lets us
/// tune generosity/cadence live once analytics show real player behaviour.
class GameConfig {
  // --- Coin economy: faucets ---
  final int startingCoins;
  final int coinsPerClear;

  /// Rewarded-ad payout for the shop's "watch a video" row. Deliberately BELOW
  /// [hintCost] so an ad never strictly dominates the coin economy (the hint
  /// funnel grants the hint directly instead of routing through coins).
  final int coinsPerRewardedAd;
  final int dailyClearBonus;

  /// Once-per-day rewarded-ad gift on the home screen.
  final int dailyGiftAdCoins;

  /// Bonus paid when a Zen chapter (10 boards) completes.
  final int chapterBonus;

  /// Flow-chain milestone bonuses: chain length -> coins (paid once per run).
  final int chainMilestone1; // at chain 3
  final int chainMilestone2; // at chain 7
  final int chainMilestone3; // at chain 15

  /// Bonus coins per gold tile on a cleared board (Zen modifier).
  final int goldTileCoins;

  // --- Coin economy: sinks ---
  final int hintCost;

  /// Streak Freeze token price (banked in advance; auto-consumed on a missed
  /// day). Max [maxFreezeTokens] held at once.
  final int streakFreezeCost;
  final int maxFreezeTokens;

  /// Streak Repair price (restore a streak broken within
  /// [streakRepairWindowHours]; offered at most once per calendar month).
  final int streakRepairCost;
  final int streakRepairWindowHours;

  /// Coin price to back-fill a missed calendar day from the archive (counts
  /// toward the monthly medal, never toward the streak).
  final int backfillCost;

  // --- Ads ---
  /// Show an interstitial every N Zen board clears (never in Daily/Premium).
  final int interstitialEveryNClears;

  /// No interstitial before this many lifetime Zen clears (habit before
  /// monetization — the "Vita Mahjong rule").
  final int firstInterstitialMinClears;

  /// Post-win rewarded "double coins" multiplier.
  final int winDoubleMultiplier;

  // --- Premium ---
  /// Free hints per local day for Premium players (replaces "unlimited", so
  /// the hint stays a meaningful object and the clean badge an achievement).
  final int premiumDailyFreeHints;

  // --- Archive ---
  /// Coins for completing an archive/backfill board (vs the live Daily's
  /// clear + bonus). Archive plays never touch the streak.
  final int archiveClearCoins;

  /// Daily Ladder bonus boards (same date, easy/hard tiers; never streak).
  final int ladderEasyCoins;
  final int ladderHardCoins;

  /// Free (non-Premium) players can open archive boards this many days back.
  final int freeArchiveDays;

  // --- Stars (efficiency; hints do NOT reduce stars — see "clean" badge) ---
  /// Wrong/bounced traces allowed for 2 stars (0 wrong ⇒ 3 stars; more ⇒ 1).
  final int starTwoStarMaxWrong;

  const GameConfig({
    this.startingCoins = 60,
    this.coinsPerClear = 12,
    this.coinsPerRewardedAd = 15,
    this.dailyClearBonus = 30,
    this.dailyGiftAdCoins = 40,
    this.chapterBonus = 40,
    this.chainMilestone1 = 10,
    this.chainMilestone2 = 20,
    this.chainMilestone3 = 40,
    this.goldTileCoins = 5,
    this.hintCost = 20,
    this.streakFreezeCost = 150,
    this.maxFreezeTokens = 2,
    this.streakRepairCost = 60,
    this.streakRepairWindowHours = 48,
    this.backfillCost = 40,
    this.interstitialEveryNClears = 7,
    this.firstInterstitialMinClears = 12,
    this.winDoubleMultiplier = 2,
    this.premiumDailyFreeHints = 5,
    this.archiveClearCoins = 21,
    this.ladderEasyCoins = 8,
    this.ladderHardCoins = 24,
    this.freeArchiveDays = 7,
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
