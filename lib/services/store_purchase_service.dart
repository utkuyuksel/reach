import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/iap_config.dart';
import 'purchase_service.dart';

/// Real [PurchaseService] backed by `in_app_purchase`. Selected only when the
/// app is built with real services enabled (see `service_config.dart`).
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  String? _price;

  @override
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );
    final resp = await _iap.queryProductDetails(IapConfig.productIds);
    if (resp.productDetails.isNotEmpty) {
      _price = resp.productDetails.first.price;
    }
  }

  @override
  bool get isAvailable => _available;

  @override
  String? get premiumPrice => _price;

  @override
  Future<void> buyPremium() async {
    final resp = await _iap.queryProductDetails(IapConfig.productIds);
    if (resp.productDetails.isEmpty) return;
    final product = resp.productDetails.firstWhere(
      (p) => p.id == IapConfig.premiumProductId,
      orElse: () => resp.productDetails.first,
    );
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  @override
  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID == IapConfig.premiumProductId &&
          (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored)) {
        _controller.add(true);
      }
      // Always finish transactions the store asks us to complete.
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  @override
  Stream<bool> get premiumStream => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
