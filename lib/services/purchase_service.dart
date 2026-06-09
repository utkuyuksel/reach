import 'dart:async';

import '../config/iap_config.dart';

/// In-app purchases behind an interface so the game runs without store accounts
/// (via [DevPurchaseService]) and so purchase logic can be mocked in tests.
///
/// Handles both the non-consumable Premium unlock and consumable coin packs.
/// Confirmed purchases/restores are delivered on [purchases] as product IDs;
/// the entitlement controller listens for the Premium id and the wallet
/// listens for coin-pack ids.
abstract class PurchaseService {
  Future<void> init();

  /// Whether the store is reachable (false ⇒ hide buy/restore UI gracefully).
  bool get isAvailable;

  /// Localized price string for [productId], or null if unknown.
  String? priceFor(String productId);

  /// Begin a purchase flow for [productId] (Premium or a coin pack). The
  /// outcome arrives on [purchases].
  Future<void> buy(String productId);

  /// Re-verify past (non-consumable) purchases. Confirmations arrive on
  /// [purchases].
  Future<void> restore();

  /// Emits a product id whenever a purchase/restore is confirmed.
  Stream<String> get purchases;

  void dispose();
}

/// No-op implementation for development and tests. "Buying" simply emits the
/// product id so the full flow (premium unlock / coin grant) is exercisable
/// without a store.
class DevPurchaseService implements PurchaseService {
  final _controller = StreamController<String>.broadcast();
  final Set<String> _ownedNonConsumables = {};

  static const _devPrices = {
    IapConfig.premiumProductId: r'$3.99',
    'com.utkuyuksel.reach.coins_small': r'$0.99',
    'com.utkuyuksel.reach.coins_medium': r'$2.99',
    'com.utkuyuksel.reach.coins_large': r'$6.99',
  };

  @override
  Future<void> init() async {}

  @override
  bool get isAvailable => true;

  @override
  String? priceFor(String productId) => _devPrices[productId];

  @override
  Future<void> buy(String productId) async {
    if (!IapConfig.isCoinPack(productId)) {
      _ownedNonConsumables.add(productId);
    }
    _controller.add(productId);
  }

  @override
  Future<void> restore() async {
    for (final id in _ownedNonConsumables) {
      _controller.add(id);
    }
  }

  @override
  Stream<String> get purchases => _controller.stream;

  @override
  void dispose() => _controller.close();
}
