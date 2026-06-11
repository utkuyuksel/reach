import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/iap_config.dart';
import '../../services/analytics_service.dart';
import '../../services/persisted_models.dart';
import '../../util/date_key.dart';
import 'daily_controller.dart';
import 'providers.dart';
import 'settings_controller.dart';

/// Holds the coin balance. Seeded with the configured starting coins on first
/// launch (granted once). Coins are spent on hints, streak protection, and
/// cosmetics; earned from clears, rewarded ads, and IAP.
///
/// Also delivers IAP contents: coin packs grant coins; the Starter Pack grants
/// coins + the exclusive Ember palette + a Streak Freeze token.
class WalletController extends Notifier<int> {
  StreamSubscription<String>? _sub;

  @override
  int build() {
    final storage = ref.read(storageServiceProvider);

    _sub = ref.read(purchaseServiceProvider).purchases.listen((productId) {
      if (IapConfig.isCoinPack(productId)) {
        earn(IapConfig.coinsFor(productId), reason: 'iap');
        ref.read(analyticsServiceProvider).log(AnalyticsEvents.purchase, {
          'product': productId,
          'coins': IapConfig.coinsFor(productId),
        });
      } else if (productId == IapConfig.starterPackProductId) {
        _deliverStarterPack();
      }
    });
    ref.onDispose(() => _sub?.cancel());

    final existing = storage.loadWallet();
    if (existing != null) return existing.coins;
    final start = ref.read(gameConfigProvider).startingCoins;
    storage.saveWallet(WalletRecord(coins: start));
    return start;
  }

  void _deliverStarterPack() {
    // Idempotent: owning the exclusive palette marks the pack as delivered
    // (restores re-emit the product id).
    final settings = ref.read(settingsControllerProvider.notifier);
    if (settings.ownsPalette(IapConfig.starterPackPaletteId)) return;
    earn(IapConfig.starterPackCoins, reason: 'starter_pack');
    settings.grantPalette(IapConfig.starterPackPaletteId);
    ref.read(dailyControllerProvider.notifier).grantFreezeToken();
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.purchase, {
      'product': IapConfig.starterPackProductId,
    });
  }

  int get coins => state;
  bool canAfford(int amount) => state >= amount;

  /// Localized price for a store product.
  String? priceFor(String productId) =>
      ref.read(purchaseServiceProvider).priceFor(productId);

  /// Begin a purchase (contents granted via the purchases stream).
  Future<void> buyPack(String productId) =>
      ref.read(purchaseServiceProvider).buy(productId);

  // ------------------------------------------------------------ daily gift

  /// Whether today's home-screen gift ad is still unclaimed.
  bool get giftAvailableToday {
    final record = ref.read(storageServiceProvider).loadWallet();
    return record?.giftDateKey != dateKeyFor(DateTime.now());
  }

  /// Grant the once-daily gift (the UI shows the rewarded ad first).
  void claimDailyGift() {
    if (!giftAvailableToday) return;
    final amount = ref.read(gameConfigProvider).dailyGiftAdCoins;
    state = state + amount;
    _persist(giftDateKey: dateKeyFor(DateTime.now()));
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.dailyGiftClaimed,
      {'amount': amount, 'balance': state},
    );
  }

  // -------------------------------------------------------------- earn/spend

  void earn(int amount, {String reason = ''}) {
    if (amount <= 0) return;
    state = state + amount;
    _persist();
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.coinsEarned,
      {'amount': amount, 'reason': reason, 'balance': state},
    );
  }

  /// Spend [amount] if affordable; returns true on success.
  bool trySpend(int amount, {String reason = ''}) {
    if (amount <= 0) return true;
    if (state < amount) return false;
    state = state - amount;
    _persist();
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.coinsSpent,
      {'amount': amount, 'reason': reason, 'balance': state},
    );
    return true;
  }

  void _persist({String? giftDateKey}) {
    final storage = ref.read(storageServiceProvider);
    final current = storage.loadWallet();
    storage.saveWallet(WalletRecord(
      coins: state,
      giftDateKey: giftDateKey ?? current?.giftDateKey,
    ));
  }
}

final walletControllerProvider =
    NotifierProvider<WalletController, int>(WalletController.new);
