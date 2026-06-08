import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Tracks Premium entitlement (a single bool). Seeds from local storage, then
/// listens to the purchase service for confirmed purchases/restores and
/// re-verifies on launch.
class EntitlementController extends Notifier<bool> {
  StreamSubscription<bool>? _sub;

  @override
  bool build() {
    final storage = ref.read(storageServiceProvider);
    final purchase = ref.read(purchaseServiceProvider);

    _sub = purchase.premiumStream.listen((owned) {
      if (owned) _grant();
    });
    ref.onDispose(() => _sub?.cancel());

    // Re-verify past purchases on launch (fire and forget).
    purchase.restore();

    return storage.loadPremium();
  }

  void _grant() {
    if (state) return;
    state = true;
    ref.read(storageServiceProvider).savePremium(true);
  }

  Future<void> buyPremium() => ref.read(purchaseServiceProvider).buyPremium();
  Future<void> restore() => ref.read(purchaseServiceProvider).restore();
}

final entitlementControllerProvider =
    NotifierProvider<EntitlementController, bool>(EntitlementController.new);
