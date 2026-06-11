import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/game/state/daily_controller.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/game/state/wallet_controller.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';
import 'package:reach/util/date_key.dart';

/// The streak system is the most state-sensitive logic in the game (date math,
/// freeze tokens, repair window, clock guard). These tests drive it with an
/// injected clock.
void main() {
  late ProviderContainer c;
  late DailyController daily;
  late DateTime clock;

  Future<void> setup() async {
    final storage = InMemoryStorageService();
    await storage.init();
    c = ProviderContainer(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      adServiceProvider.overrideWithValue(DevAdService()),
      purchaseServiceProvider.overrideWithValue(DevPurchaseService()),
      analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
      remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService()),
    ]);
    clock = DateTime(2026, 6, 10, 9, 0); // a fixed local morning
    daily = c.read(dailyControllerProvider.notifier)..now = () => clock;
    c.read(dailyControllerProvider); // build
  }

  /// Complete "today" according to the fake clock, then advance [days].
  void completeAndAdvance({int days = 1}) {
    daily.recordCompletion(dateKey: dateKeyFor(clock));
    clock = clock.add(Duration(days: days));
  }

  group('streak basics', () {
    test('consecutive days build the streak', () async {
      await setup();
      completeAndAdvance();
      completeAndAdvance();
      completeAndAdvance();
      expect(c.read(dailyControllerProvider).currentStreak, 3);
      expect(daily.effectiveStreak, 3); // played yesterday → alive
    });

    test('a missed day with no protection breaks the streak (and parks it)',
        () async {
      await setup();
      completeAndAdvance();
      completeAndAdvance(days: 2); // miss one day
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      final r = c.read(dailyControllerProvider);
      expect(r.currentStreak, 1);
      expect(r.brokenStreak, 2); // parked for repair
      expect(r.longestStreak, 2);
    });

    test('effectiveStreak shows 0 once the streak is unrescuable (stale-display fix)',
        () async {
      await setup();
      completeAndAdvance();
      completeAndAdvance();
      // Two days pass with no play and no freeze tokens.
      clock = clock.add(const Duration(days: 2));
      expect(c.read(dailyControllerProvider).currentStreak, 2); // stored
      expect(daily.effectiveStreak, 0); // displayed honestly
    });
  });

  group('freeze tokens', () {
    test('a banked freeze absorbs a missed day', () async {
      await setup();
      // Fund and bank one freeze.
      c.read(walletControllerProvider.notifier).earn(500, reason: 'test');
      completeAndAdvance();
      completeAndAdvance();
      expect(daily.buyFreezeToken(), isTrue);

      clock = clock.add(const Duration(days: 1)); // miss exactly one day
      expect(daily.effectiveStreak, 2); // still alive thanks to the token
      final used = daily.recordCompletion(dateKey: dateKeyFor(clock));
      expect(used, 1); // one token consumed
      final r = c.read(dailyControllerProvider);
      expect(r.currentStreak, 3); // unbroken
      expect(r.freezeTokens, 0);
    });

    test('the token bank is capped', () async {
      await setup();
      c.read(walletControllerProvider.notifier).earn(1000, reason: 'test');
      final cap = c.read(gameConfigProvider).maxFreezeTokens;
      for (var i = 0; i < cap; i++) {
        expect(daily.buyFreezeToken(), isTrue);
      }
      expect(daily.buyFreezeToken(), isFalse); // at cap
      expect(c.read(dailyControllerProvider).freezeTokens, cap);
    });
  });

  group('streak repair', () {
    test('a recent break can be repaired once, for coins', () async {
      await setup();
      c.read(walletControllerProvider.notifier).earn(500, reason: 'test');
      completeAndAdvance();
      completeAndAdvance();
      completeAndAdvance(days: 3); // break (2 missed days)
      daily.recordCompletion(dateKey: dateKeyFor(clock)); // streak resets to 1

      expect(daily.repairAvailable, isTrue);
      final coinsBefore = c.read(walletControllerProvider);
      expect(daily.repairStreak(), isTrue);
      final r = c.read(dailyControllerProvider);
      expect(r.currentStreak, 4); // 3 parked + 1 since the break
      expect(r.brokenStreak, 0);
      expect(
        c.read(walletControllerProvider),
        coinsBefore - c.read(gameConfigProvider).streakRepairCost,
      );
      expect(daily.repairAvailable, isFalse); // once per month
    });

    test('the repair window closes', () async {
      await setup();
      c.read(walletControllerProvider.notifier).earn(500, reason: 'test');
      completeAndAdvance();
      completeAndAdvance(days: 3);
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      expect(daily.repairAvailable, isTrue);
      clock = clock.add(const Duration(hours: 49)); // past the 48h window
      expect(daily.repairAvailable, isFalse);
    });
  });

  group('clock integrity', () {
    test('a rolled-back clock cannot re-credit an earlier day', () async {
      await setup();
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      clock = clock.add(const Duration(days: 1));
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      expect(c.read(dailyControllerProvider).currentStreak, 2);
      // Roll the clock BACK to the first day: not today's key → rejected;
      // even if "today" matched, the gap<=0 branch gives no extra credit.
      clock = clock.subtract(const Duration(days: 1));
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      expect(c.read(dailyControllerProvider).currentStreak, 2);
    });

    test('honest late-night → early-morning play still credits the streak',
        () async {
      await setup();
      clock = DateTime(2026, 6, 10, 23, 50);
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      clock = DateTime(2026, 6, 11, 0, 10); // 20 minutes later, next day
      daily.recordCompletion(dateKey: dateKeyFor(clock));
      expect(c.read(dailyControllerProvider).currentStreak, 2);
    });

    test('only today\'s board can touch the streak', () async {
      await setup();
      daily.recordCompletion(dateKey: '2020-01-01'); // bogus past key
      expect(c.read(dailyControllerProvider).results, isEmpty);
    });
  });

  group('calendar + medals', () {
    test('archive completions count toward the medal but not the streak',
        () async {
      await setup();
      for (var d = 1; d <= 20; d++) {
        daily.recordArchiveCompletion(
            dateKey: '2026-05-${d.toString().padLeft(2, '0')}');
      }
      expect(daily.completionsInMonth('2026-05'), 20);
      expect(daily.medalForMonth('2026-05'), MonthMedal.bronze);
      expect(c.read(dailyControllerProvider).currentStreak, 0);
    });

    test('medal tiers: bronze 20, silver 25, gold = full month', () async {
      await setup();
      for (var d = 1; d <= 25; d++) {
        daily.recordArchiveCompletion(
            dateKey: '2026-04-${d.toString().padLeft(2, '0')}');
      }
      expect(daily.medalForMonth('2026-04'), MonthMedal.silver);
      for (var d = 26; d <= 30; d++) {
        daily.recordArchiveCompletion(
            dateKey: '2026-04-${d.toString().padLeft(2, '0')}');
      }
      expect(daily.medalForMonth('2026-04'), MonthMedal.gold);
    });
  });
}
