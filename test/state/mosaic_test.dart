import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/config/iap_config.dart';
import 'package:reach/game/state/entitlement_controller.dart';
import 'package:reach/game/state/mosaic_controller.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';
import 'package:reach/util/date_key.dart';

void main() {
  late ProviderContainer c;
  late MosaicController mosaic;
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
    clock = DateTime(2026, 6, 10, 9); // a Wednesday
    mosaic = c.read(mosaicControllerProvider.notifier)..now = () => clock;
    c.read(mosaicControllerProvider);
  }

  test('clears reveal cells, clamped at the mosaic size', () async {
    await setup();
    final config = c.read(gameConfigProvider);
    mosaic.onBoardCleared();
    expect(mosaic.revealed, config.mosaicRevealPerClear);
    for (var i = 0; i < 100; i++) {
      mosaic.onBoardCleared();
    }
    expect(mosaic.revealed, config.mosaicSize); // clamped, complete
    expect(mosaic.isComplete, isTrue);
  });

  test('Premium reveals a bonus cell per clear', () async {
    await setup();
    final config = c.read(gameConfigProvider);
    // Instantiate the entitlement listener BEFORE buying (the broadcast
    // stream drops events with no subscriber), then grant premium.
    c.read(entitlementControllerProvider);
    await c
        .read(purchaseServiceProvider)
        .buy(IapConfig.premiumProductId);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(entitlementControllerProvider), isTrue);
    mosaic.onBoardCleared();
    expect(
      mosaic.revealed,
      config.mosaicRevealPerClear + config.premiumMosaicBonus,
    );
  });

  test('the week rolls over: old artwork banks into the gallery', () async {
    await setup();
    mosaic.onBoardCleared();
    final firstWeek = weekKeyFor(clock);
    final progress = mosaic.revealed;

    clock = clock.add(const Duration(days: 7)); // next week
    expect(mosaic.revealed, 0); // fresh canvas
    mosaic.onBoardCleared(); // triggers rollover persistence
    final record = c.read(mosaicControllerProvider);
    expect(record.gallery[firstWeek], progress); // banked as it was
    expect(record.weekKey, weekKeyFor(clock));
  });
}
