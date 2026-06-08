import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/iap_config.dart';
import '../../services/analytics_service.dart';
import 'providers.dart';

/// Tracks Premium entitlement (a single bool). Seeds from local storage, then
/// listens to the purchase service for a confirmed Premium purchase/restore
/// and re-verifies on launch.
class EntitlementController extends Notifier<bool> {
  StreamSubscription<String>? _sub;

  @override
  bool build() {
    final storage = ref.read(storageServiceProvider);
    final purchase = ref.read(purchaseServiceProvider);

    _sub = purchase.purchases.listen((productId) {
      if (productId == IapConfig.premiumProductId) _grant();
    });
    ref.onDispose(() => _sub?.cancel());

    purchase.restore(); // re-verify on launch (fire and forget)
    return storage.loadPremium();
  }

  /// Localized Premium price for display.
  String? get price =>
      ref.read(purchaseServiceProvider).priceFor(IapConfig.premiumProductId);

  void _grant() {
    if (state) return;
    state = true;
    ref.read(storageServiceProvider).savePremium(true);
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.purchase, {
      'product': IapConfig.premiumProductId,
    });
  }

  Future<void> buyPremium() =>
      ref.read(purchaseServiceProvider).buy(IapConfig.premiumProductId);
  Future<void> restore() {
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.restore);
    return ref.read(purchaseServiceProvider).restore();
  }
}

final entitlementControllerProvider =
    NotifierProvider<EntitlementController, bool>(EntitlementController.new);
