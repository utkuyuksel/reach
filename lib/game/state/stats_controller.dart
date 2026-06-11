import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/persisted_models.dart';
import '../../util/date_key.dart';
import 'providers.dart';

/// Cumulative cross-mode counters (the badge shelf's data) and the Premium
/// daily free-hint quota.
class StatsController extends Notifier<StatsRecord> {
  /// Injected clock (tests override); defaults to the real time.
  DateTime Function() now = DateTime.now;

  @override
  StatsRecord build() => ref.read(storageServiceProvider).loadStats();

  /// Record a board win (any mode). [threeStarDaily] marks a 3-star live
  /// Daily completion.
  void recordWin({required bool clean, bool threeStarDaily = false}) {
    _save(state.copyWith(
      totalClears: state.totalClears + 1,
      cleanClears: clean ? state.cleanClears + 1 : state.cleanClears,
      threeStarDailies:
          threeStarDaily ? state.threeStarDailies + 1 : state.threeStarDailies,
    ));
  }

  /// Premium free hints remaining today (resets at local midnight).
  int freeHintsLeft(int dailyAllowance) {
    final today = dateKeyFor(now());
    final used = state.hintQuotaDateKey == today ? state.hintQuotaUsed : 0;
    final left = dailyAllowance - used;
    return left < 0 ? 0 : left;
  }

  /// Consume one Premium free hint. Returns false if the quota is exhausted.
  bool useFreeHint(int dailyAllowance) {
    final today = dateKeyFor(now());
    final used = state.hintQuotaDateKey == today ? state.hintQuotaUsed : 0;
    if (used >= dailyAllowance) return false;
    _save(state.copyWith(hintQuotaDateKey: today, hintQuotaUsed: used + 1));
    return true;
  }

  void _save(StatsRecord updated) {
    state = updated;
    ref.read(storageServiceProvider).saveStats(updated);
  }
}

final statsControllerProvider =
    NotifierProvider<StatsController, StatsRecord>(StatsController.new);
