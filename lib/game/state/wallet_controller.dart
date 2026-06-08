import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/iap_config.dart';
import '../../services/analytics_service.dart';
import '../../services/persisted_models.dart';
import 'providers.dart';

/// Holds the coin balance. Seeded with the configured starting coins on first
/// launch (granted once). Coins are spent on hints and cosmetic themes, and
/// earned from clears, rewarded ads, and IAP coin packs.
class WalletController extends Notifier<int> {
  StreamSubscription<String>? _sub;

  @override
  int build() {
    final storage = ref.read(storageServiceProvider);

    // Grant coins when a coin-pack purchase confirms.
    _sub = ref.read(purchaseServiceProvider).purchases.listen((productId) {
      if (IapConfig.isCoinPack(productId)) {
        earn(IapConfig.coinsFor(productId), reason: 'iap');
        ref.read(analyticsServiceProvider).log(AnalyticsEvents.purchase, {
          'product': productId,
          'coins': IapConfig.coinsFor(productId),
        });
      }
    });
    ref.onDispose(() => _sub?.cancel());

    final existing = storage.loadWallet();
    if (existing != null) return existing.coins;
    final start = ref.read(gameConfigProvider).startingCoins;
    storage.saveWallet(WalletRecord(coins: start));
    return start;
  }

  int get coins => state;
  bool canAfford(int amount) => state >= amount;

  /// Localized price for a coin pack.
  String? priceFor(String productId) =>
      ref.read(purchaseServiceProvider).priceFor(productId);

  /// Begin a coin-pack purchase (coins granted via the purchases stream).
  Future<void> buyPack(String productId) =>
      ref.read(purchaseServiceProvider).buy(productId);

  void earn(int amount, {String reason = ''}) {
    if (amount <= 0) return;
    _set(state + amount);
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.coinsEarned,
      {'amount': amount, 'reason': reason, 'balance': state},
    );
  }

  /// Spend [amount] if affordable; returns true on success.
  bool trySpend(int amount, {String reason = ''}) {
    if (amount <= 0) return true;
    if (state < amount) return false;
    _set(state - amount);
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.coinsSpent,
      {'amount': amount, 'reason': reason, 'balance': state},
    );
    return true;
  }

  void _set(int value) {
    state = value;
    ref.read(storageServiceProvider).saveWallet(WalletRecord(coins: value));
  }
}

final walletControllerProvider =
    NotifierProvider<WalletController, int>(WalletController.new);
