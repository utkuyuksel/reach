import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../services/persisted_models.dart';
import '../../util/date_key.dart';
import 'entitlement_controller.dart';
import 'providers.dart';

/// The always-on weekly mosaic: every cleared board (any mode) reveals a few
/// cells of this week's deterministic artwork; the week rolls over on Monday
/// and finished (or not) artworks are banked into the gallery. No opt-in, no
/// penalty, no popups — the home card's slowly-appearing picture IS the event.
class MosaicController extends Notifier<MosaicRecord> {
  /// Injected clock (tests override); defaults to the real time.
  DateTime Function() now = DateTime.now;

  @override
  MosaicRecord build() =>
      _rolledOver(ref.read(storageServiceProvider).loadMosaic());

  /// Current week's reveal progress (rollover-safe to read any time).
  int get revealed => _rolledOver(state).revealed;

  bool get isComplete =>
      revealed >= ref.read(gameConfigProvider).mosaicSize;

  String get currentWeekKey => weekKeyFor(now());

  /// Archive a finished week and start the new one when Monday passes.
  MosaicRecord _rolledOver(MosaicRecord r) {
    final week = weekKeyFor(now());
    if (r.weekKey == week) return r;
    var next = r;
    if (r.weekKey != null) {
      next = r.copyWith(
        gallery: {...r.gallery, r.weekKey!: r.revealed},
      );
    }
    next = next.copyWith(weekKey: week, revealed: 0);
    if (!identical(next, r)) _persistOnly(next);
    return next;
  }

  /// Called on every fresh board clear: reveal a few more cells. Returns the
  /// completion chest (coins) when this clear FINISHES the week's artwork,
  /// 0 otherwise — the caller folds it into the win's coin total.
  int onBoardCleared() {
    final config = ref.read(gameConfigProvider);
    var r = _rolledOver(state);
    if (r.revealed >= config.mosaicSize) {
      if (!identical(r, state)) _save(r);
      return 0; // this week's artwork is already finished
    }
    final premium = ref.read(entitlementControllerProvider);
    final step = config.mosaicRevealPerClear +
        (premium ? config.premiumMosaicBonus : 0);
    final revealed = (r.revealed + step).clamp(0, config.mosaicSize);
    r = r.copyWith(revealed: revealed);
    _save(r);
    if (revealed >= config.mosaicSize) {
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.mosaicComplete, {'week': r.weekKey});
      return config.mosaicCompleteBonus; // the weekly chest
    }
    return 0;
  }

  void _save(MosaicRecord r) {
    state = r;
    ref.read(storageServiceProvider).saveMosaic(r);
  }

  void _persistOnly(MosaicRecord r) =>
      ref.read(storageServiceProvider).saveMosaic(r);
}

final mosaicControllerProvider =
    NotifierProvider<MosaicController, MosaicRecord>(MosaicController.new);
