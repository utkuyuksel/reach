import 'package:flutter/foundation.dart';

/// Analytics behind an interface so we can ship a no-op in tests, a console
/// logger in dev, and wire a real provider (e.g. Firebase Analytics) later
/// without touching call sites. Instrumenting from day one is what lets us
/// answer "does it retain?" before scaling ad spend.
abstract class AnalyticsService {
  Future<void> init();
  void log(String event, [Map<String, Object?> params = const {}]);
}

/// Canonical event names (avoid typos at call sites).
class AnalyticsEvents {
  AnalyticsEvents._();
  static const boardStart = 'board_start';
  static const boardClear = 'board_clear';
  static const hintRequested = 'hint_requested';
  static const hintShown = 'hint_shown';
  static const hintNoCoins = 'hint_no_coins';
  static const rewardedAdShown = 'rewarded_ad_shown';
  static const interstitialShown = 'interstitial_shown';
  static const coinsEarned = 'coins_earned';
  static const coinsSpent = 'coins_spent';
  static const purchase = 'purchase';
  static const restore = 'restore';
  static const dailyCompleted = 'daily_completed';
  static const undo = 'undo';
  static const restart = 'restart';

  // Onboarding funnel — do new players finish learning the mechanic?
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';

  // Viral / distribution funnel — the share is the growth engine.
  static const shareOpened = 'share_opened';
  static const shareCompleted = 'share_completed';

  // Monetization funnel top.
  static const shopOpened = 'shop_opened';

  // Streak economy.
  static const streakFreezeUsed = 'streak_freeze_used';
  static const streakFreezeBought = 'streak_freeze_bought';
  static const streakRepaired = 'streak_repaired';

  // Zen structure.
  static const chapterComplete = 'chapter_complete';
  static const chainMilestone = 'chain_milestone';

  // New reward surfaces.
  static const dailyGiftClaimed = 'daily_gift_claimed';
  static const winCoinsDoubled = 'win_coins_doubled';

  // Calendar / archive.
  static const archivePlayed = 'archive_played';
  static const calendarOpened = 'calendar_opened';

  // Meta.
  static const badgeEarned = 'badge_earned';
}

/// Does nothing (tests, or until a real provider is wired).
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> init() async {}
  @override
  void log(String event, [Map<String, Object?> params = const {}]) {}
}

/// Prints events to the console — useful during development.
class DebugAnalyticsService implements AnalyticsService {
  @override
  Future<void> init() async {}

  @override
  void log(String event, [Map<String, Object?> params = const {}]) {
    debugPrint('[analytics] $event ${params.isEmpty ? '' : params}');
  }
}
