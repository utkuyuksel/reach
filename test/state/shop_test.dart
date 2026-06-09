import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/config/iap_config.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/game/state/settings_controller.dart';
import 'package:reach/game/state/wallet_controller.dart';
import 'package:reach/game/theme/palette.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';
import 'package:reach/services/sound_service.dart';

Future<ProviderContainer> _container() async {
  final storage = InMemoryStorageService();
  await storage.init();
  return ProviderContainer(overrides: [
    storageServiceProvider.overrideWithValue(storage),
    adServiceProvider.overrideWithValue(DevAdService()),
    purchaseServiceProvider.overrideWithValue(DevPurchaseService()),
    analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
    remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService()),
    soundServiceProvider.overrideWithValue(NoopSoundService()),
  ]);
}

void main() {
  test('buying a coin pack grants its coins', () async {
    final c = await _container();
    final start = c.read(walletControllerProvider); // builds + subscribes
    const pack = 'com.utkuyuksel.reach.coins_small';

    await c.read(walletControllerProvider.notifier).buyPack(pack);
    await Future<void>.delayed(Duration.zero); // let the purchases stream deliver

    expect(c.read(walletControllerProvider), start + IapConfig.coinsFor(pack));
  });

  test('buying a palette unlocks, selects, and deducts coins', () async {
    final c = await _container();
    c.read(walletControllerProvider.notifier).earn(300, reason: 'test');
    final coinsBefore = c.read(walletControllerProvider);

    final ok =
        c.read(settingsControllerProvider.notifier).buyPalette(GamePalette.sage);

    expect(ok, isTrue);
    expect(c.read(settingsControllerProvider).ownedPaletteIds, contains('sage'));
    expect(c.read(settingsControllerProvider).paletteId, 'sage');
    expect(c.read(walletControllerProvider),
        coinsBefore - GamePalette.sage.coinPrice);
    // Now selectable as the active palette.
    expect(c.read(paletteProvider).id, 'sage');
  });

  test('buying a palette fails without enough coins (no change)', () async {
    final c = await _container();
    // Starting coins are well below the Ink palette price.
    final ok =
        c.read(settingsControllerProvider.notifier).buyPalette(GamePalette.noir);

    expect(ok, isFalse);
    expect(c.read(settingsControllerProvider).ownedPaletteIds, isEmpty);
    expect(c.read(settingsControllerProvider).paletteId, 'clay');
  });

  test('Premium unlocks all palettes without owning them', () async {
    final c = await _container();
    final ctrl = c.read(settingsControllerProvider.notifier);
    expect(ctrl.isUnlocked(GamePalette.dusk, premium: false), isFalse);
    expect(ctrl.isUnlocked(GamePalette.dusk, premium: true), isTrue);
    expect(ctrl.isUnlocked(GamePalette.clay, premium: false), isTrue); // free
  });
}
