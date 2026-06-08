import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../services/persisted_models.dart';
import 'providers.dart';

/// Holds the coin balance. On first ever launch the wallet is seeded with the
/// configured starting coins (granted once). Coins are spent on hints and
/// earned from clears, rewarded ads, and (later) IAP packs.
class WalletController extends Notifier<int> {
  @override
  int build() {
    final storage = ref.read(storageServiceProvider);
    final existing = storage.loadWallet();
    if (existing != null) return existing.coins;
    // First launch — grant starting coins once.
    final start = ref.read(gameConfigProvider).startingCoins;
    storage.saveWallet(WalletRecord(coins: start));
    return start;
  }

  int get coins => state;

  bool canAfford(int amount) => state >= amount;

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
