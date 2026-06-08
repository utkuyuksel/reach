import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/persisted_models.dart';
import '../../util/date_key.dart';
import 'providers.dart';

/// Tracks Daily Challenge completion and streaks.
class DailyController extends Notifier<DailyRecord> {
  @override
  DailyRecord build() => ref.read(storageServiceProvider).loadDaily();

  /// Record today's completion and update the streak. Idempotent per date.
  void recordCompletion({
    required String dateKey,
    int hintsUsed = 0,
    int stars = 3,
  }) {
    if (state.isCompleted(dateKey)) return;

    final date = dateFromKey(dateKey);
    final last = state.lastCompletedDate;
    final int newStreak;
    if (last != null && isDayBefore(dateFromKey(last), date)) {
      newStreak = state.currentStreak + 1;
    } else {
      newStreak = 1;
    }
    final longest =
        newStreak > state.longestStreak ? newStreak : state.longestStreak;

    final results = Map<String, DailyResult>.from(state.results)
      ..[dateKey] =
          DailyResult(dateKey: dateKey, hintsUsed: hintsUsed, stars: stars);

    final updated = state.copyWith(
      currentStreak: newStreak,
      longestStreak: longest,
      lastCompletedDate: dateKey,
      results: results,
    );
    state = updated;
    ref.read(storageServiceProvider).saveDaily(updated);
  }
}

final dailyControllerProvider =
    NotifierProvider<DailyController, DailyRecord>(DailyController.new);
