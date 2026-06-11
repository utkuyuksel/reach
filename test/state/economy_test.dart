import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/config/iap_config.dart';
import 'package:reach/game/state/daily_controller.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/game/state/settings_controller.dart';
import 'package:reach/game/state/stats_controller.dart';
import 'package:reach/game/state/wallet_controller.dart';
import 'package:reach/game/theme/palette.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';

void main() {
  late ProviderContainer c;
  late DevPurchaseService purchase;

  Future<void> setup() async {
    final storage = InMemoryStorageService();
    await storage.init();
    purchase = DevPurchaseService();
    c = ProviderContainer(overrides: [
      storageServiceProvider.overrideWithValue(storage),
      adServiceProvider.overrideWithValue(DevAdService()),
      purchaseServiceProvider.overrideWithValue(purchase),
      analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
      remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService()),
    ]);
  }

  group('starter pack', () {
    test('delivers coins + the exclusive Ember palette + a freeze token',
        () async {
      await setup();
      final start = c.read(walletControllerProvider);
      await c
          .read(walletControllerProvider.notifier)
          .buyPack(IapConfig.starterPackProductId);
      await Future<void>.delayed(Duration.zero); // let the stream deliver

      expect(c.read(walletControllerProvider),
          start + IapConfig.starterPackCoins);
      expect(
        c
            .read(settingsControllerProvider.notifier)
            .ownsPalette(IapConfig.starterPackPaletteId),
        isTrue,
      );
      expect(c.read(dailyControllerProvider).freezeTokens, 1);
    });

    test('a restore re-emit cannot double-deliver', () async {
      await setup();
      final wallet = c.read(walletControllerProvider.notifier);
      await wallet.buyPack(IapConfig.starterPackProductId);
      await Future<void>.delayed(Duration.zero);
      final after = c.read(walletControllerProvider);

      await purchase.restore(); // dev impl re-emits owned non-consumables
      await Future<void>.delayed(Duration.zero);
      expect(c.read(walletControllerProvider), after); // unchanged
      expect(c.read(dailyControllerProvider).freezeTokens, 1);
    });
  });

  group('exclusive palettes', () {
    test('cannot be bought with coins and are not unlocked by Premium',
        () async {
      await setup();
      final settings = c.read(settingsControllerProvider.notifier);
      c.read(walletControllerProvider.notifier).earn(99999, reason: 'test');
      expect(settings.buyPalette(GamePalette.ember), isFalse);
      expect(settings.isUnlocked(GamePalette.ember, premium: true), isFalse);
      settings.grantPalette(GamePalette.ember.id);
      expect(settings.isUnlocked(GamePalette.ember, premium: false), isTrue);
    });

    test('coin palettes still purchase and select normally', () async {
      await setup();
      final settings = c.read(settingsControllerProvider.notifier);
      c.read(walletControllerProvider.notifier).earn(2000, reason: 'test');
      expect(settings.buyPalette(GamePalette.midnight), isTrue);
      expect(c.read(settingsControllerProvider).paletteId, 'midnight');
    });
  });

  group('premium hint quota', () {
    test('grants the daily allowance, then refuses', () async {
      await setup();
      final stats = c.read(statsControllerProvider.notifier);
      final allowance = c.read(gameConfigProvider).premiumDailyFreeHints;
      var clock = DateTime(2026, 6, 10, 9);
      stats.now = () => clock;

      for (var i = 0; i < allowance; i++) {
        expect(stats.useFreeHint(allowance), isTrue);
      }
      expect(stats.useFreeHint(allowance), isFalse);
      expect(stats.freeHintsLeft(allowance), 0);

      clock = clock.add(const Duration(days: 1)); // local midnight reset
      expect(stats.freeHintsLeft(allowance), allowance);
      expect(stats.useFreeHint(allowance), isTrue);
    });
  });

  group('daily gift', () {
    test('claimable once per local day', () async {
      await setup();
      final wallet = c.read(walletControllerProvider.notifier);
      final config = c.read(gameConfigProvider);
      final start = c.read(walletControllerProvider);

      expect(wallet.giftAvailableToday, isTrue);
      wallet.claimDailyGift();
      expect(
          c.read(walletControllerProvider), start + config.dailyGiftAdCoins);
      expect(wallet.giftAvailableToday, isFalse);
      wallet.claimDailyGift(); // no-op
      expect(
          c.read(walletControllerProvider), start + config.dailyGiftAdCoins);
    });
  });

  group('pack curve', () {
    test('coin packs grant their configured amounts (monotonic value curve)',
        () {
      expect(IapConfig.coinsFor('com.utkuyuksel.reach.coins_small'), 200);
      expect(IapConfig.coinsFor('com.utkuyuksel.reach.coins_medium'), 800);
      expect(IapConfig.coinsFor('com.utkuyuksel.reach.coins_large'), 2200);
      // Value per dollar strictly improves up the ladder ($0.99/2.99/6.99).
      expect(200 / 0.99 < 800 / 2.99, isTrue);
      expect(800 / 2.99 < 2200 / 6.99, isTrue);
    });
  });

  group('stats counters', () {
    test('recordWin aggregates clears, clean clears, and 3-star dailies',
        () async {
      await setup();
      final stats = c.read(statsControllerProvider.notifier);
      stats.recordWin(clean: true, threeStarDaily: true);
      stats.recordWin(clean: false);
      final r = c.read(statsControllerProvider);
      expect(r.totalClears, 2);
      expect(r.cleanClears, 1);
      expect(r.threeStarDailies, 1);
    });
  });
}
