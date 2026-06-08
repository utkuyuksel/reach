import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/iap_config.dart';
import 'purchase_service.dart';

/// Real [PurchaseService] backed by `in_app_purchase`. Selected only when the
/// app is built with real services enabled (see `service_config.dart`).
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = {};
  bool _available = false;

  @override
  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    final resp = await _iap.queryProductDetails(IapConfig.productIds);
    for (final p in resp.productDetails) {
      _products[p.id] = p;
    }
  }

  @override
  bool get isAvailable => _available;

  @override
  String? priceFor(String productId) => _products[productId]?.price;

  @override
  Future<void> buy(String productId) async {
    final product = _products[productId];
    if (product == null) return;
    final param = PurchaseParam(productDetails: product);
    if (IapConfig.isCoinPack(productId)) {
      await _iap.buyConsumable(purchaseParam: param); // auto-consumed
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  @override
  Future<void> restore() async => _iap.restorePurchases();

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _controller.add(p.productID);
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }

  @override
  Stream<String> get purchases => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
