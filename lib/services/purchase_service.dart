import 'dart:async';

/// In-app purchases behind an interface so the game runs without store accounts
/// (via [DevPurchaseService]) and so purchase logic can be mocked in tests.
///
/// There is a single non-consumable "Premium" product. Premium removes ads,
/// grants unlimited hints, and unlocks cosmetic palettes. Entitlement changes
/// are delivered on [premiumStream]; call [restore] on launch to re-verify.
abstract class PurchaseService {
  Future<void> init();

  /// Whether the store is reachable (false ⇒ hide buy/restore UI gracefully).
  bool get isAvailable;

  /// Localized price string for Premium, or `null` if unknown.
  String? get premiumPrice;

  /// Begin a purchase flow. The outcome arrives on [premiumStream].
  Future<void> buyPremium();

  /// Re-verify past purchases. Confirmed entitlements arrive on [premiumStream].
  Future<void> restore();

  /// Emits `true` whenever Premium ownership is confirmed (purchased/restored).
  Stream<bool> get premiumStream;

  void dispose();
}

/// No-op implementation for development and tests. "Buying" simply flips the
/// entitlement so the full Premium experience is exercisable without a store.
class DevPurchaseService implements PurchaseService {
  final _controller = StreamController<bool>.broadcast();
  bool _premium = false;

  @override
  Future<void> init() async {}

  @override
  bool get isAvailable => true;

  @override
  String? get premiumPrice => r'$3.99';

  @override
  Future<void> buyPremium() async {
    _premium = true;
    _controller.add(true);
  }

  @override
  Future<void> restore() async {
    _controller.add(_premium);
  }

  @override
  Stream<bool> get premiumStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }
}
