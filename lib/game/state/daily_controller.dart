import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../services/persisted_models.dart';
import '../../util/date_key.dart';
import 'providers.dart';
import 'wallet_controller.dart';

/// The monthly-medal tiers for the Daily calendar.
enum MonthMedal { none, bronze, silver, gold }

/// Tracks Daily Challenge completion, streaks (with Freeze/Repair protection),
/// the calendar results map, and monthly medals.
///
/// Streak rules:
///  * Completing on the day after the last completion → streak + 1.
///  * Missed days are absorbed by banked Streak Freeze tokens (one per missed
///    day, consumed automatically at the next completion).
///  * Otherwise the streak breaks: its value is parked in [DailyRecord.brokenStreak]
///    so a Streak Repair (within the repair window, once per calendar month)
///    can restore it.
///  * Clock-rollback guard: a streak increment requires ≥20h since the last
///    streak-credited completion; the play and the calendar entry always count.
class DailyController extends Notifier<DailyRecord> {
  /// Injected clock (tests override); defaults to the real time.
  DateTime Function() now = DateTime.now;

  @override
  DailyRecord build() => ref.read(storageServiceProvider).loadDaily();

  // ---------------------------------------------------------------- streak

  /// The streak to DISPLAY right now: the stored value while it is still
  /// alive (played today/yesterday, or every missed day so far is covered by
  /// banked freeze tokens), otherwise 0. Fixes the stale-streak display.
  int get effectiveStreak {
    final last = state.lastCompletedDate;
    if (last == null || state.currentStreak == 0) return 0;
    final gap = daysBetween(dateFromKey(last), now());
    if (gap <= 1) return state.currentStreak;
    return (gap - 1) <= state.freezeTokens ? state.currentStreak : 0;
  }

  /// Record today's completion and update the streak. Idempotent per date.
  /// Returns the number of freeze tokens consumed (for a gentle ❄ note).
  int recordCompletion({
    required String dateKey,
    int hintsUsed = 0,
    int stars = 3,
  }) {
    if (state.isCompleted(dateKey)) return 0;
    final today = dateKeyFor(now());
    if (dateKey != today) return 0; // only today's board can touch the streak

    final last = state.lastCompletedDate;
    final nowMs = now().millisecondsSinceEpoch;
    // Clock-rollback guard: the play always records; the INCREMENT needs ≥20h.
    final creditable =
        nowMs - state.lastCompletedAtMillis >= const Duration(hours: 20).inMilliseconds;

    var freezeTokens = state.freezeTokens;
    var brokenStreak = state.brokenStreak;
    var brokenAt = state.brokenAtMillis;
    var usedFreezes = 0;
    final int newStreak;

    if (last == null) {
      newStreak = 1;
    } else {
      final gap = daysBetween(dateFromKey(last), dateFromKey(dateKey));
      if (gap <= 0) {
        newStreak = state.currentStreak; // same-day edge: no double credit
      } else if (gap == 1) {
        newStreak = creditable ? state.currentStreak + 1 : state.currentStreak;
      } else if (gap - 1 <= freezeTokens) {
        usedFreezes = gap - 1;
        freezeTokens -= usedFreezes;
        newStreak = creditable ? state.currentStreak + 1 : state.currentStreak;
      } else {
        // Break: park the old streak so a Repair can restore it.
        brokenStreak = state.currentStreak;
        brokenAt = nowMs;
        newStreak = 1;
      }
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
      freezeTokens: freezeTokens,
      brokenStreak: brokenStreak,
      brokenAtMillis: brokenAt,
      lastCompletedAtMillis: creditable ? nowMs : state.lastCompletedAtMillis,
    );
    _save(updated);
    if (usedFreezes > 0) {
      ref.read(analyticsServiceProvider).log(
        AnalyticsEvents.streakFreezeUsed,
        {'tokens': usedFreezes, 'streak': newStreak},
      );
    }
    return usedFreezes;
  }

  // ------------------------------------------------------- freeze + repair

  /// Grant a freeze token without payment (Starter Pack delivery). Respects
  /// the bank cap.
  void grantFreezeToken() {
    final cap = ref.read(gameConfigProvider).maxFreezeTokens;
    if (state.freezeTokens >= cap) return;
    _save(state.copyWith(freezeTokens: state.freezeTokens + 1));
  }

  /// Buy one Streak Freeze token with coins. Returns false when at the cap or
  /// the player can't afford it.
  bool buyFreezeToken() {
    final config = ref.read(gameConfigProvider);
    if (state.freezeTokens >= config.maxFreezeTokens) return false;
    final wallet = ref.read(walletControllerProvider.notifier);
    if (!wallet.trySpend(config.streakFreezeCost, reason: 'streak_freeze')) {
      return false;
    }
    _save(state.copyWith(freezeTokens: state.freezeTokens + 1));
    return true;
  }

  /// A Streak Repair is offered when a streak broke recently (within the
  /// window), there is something to restore, and this month's repair is
  /// unused. The offer is shown quietly on the calendar — never a popup.
  bool get repairAvailable {
    if (state.brokenStreak <= 0) return false;
    final config = ref.read(gameConfigProvider);
    final windowMs =
        Duration(hours: config.streakRepairWindowHours).inMilliseconds;
    if (now().millisecondsSinceEpoch - state.brokenAtMillis > windowMs) {
      return false;
    }
    return state.lastRepairMonth != monthKeyFor(now());
  }

  /// Restore the broken streak for coins. The restored value is the parked
  /// streak plus the completions since the break (already counted in
  /// [DailyRecord.currentStreak]).
  bool repairStreak() {
    if (!repairAvailable) return false;
    final config = ref.read(gameConfigProvider);
    final wallet = ref.read(walletControllerProvider.notifier);
    if (!wallet.trySpend(config.streakRepairCost, reason: 'streak_repair')) {
      return false;
    }
    final restored = state.brokenStreak + state.currentStreak;
    final longest =
        restored > state.longestStreak ? restored : state.longestStreak;
    _save(state.copyWith(
      currentStreak: restored,
      longestStreak: longest,
      brokenStreak: 0,
      brokenAtMillis: 0,
      lastRepairMonth: monthKeyFor(now()),
    ));
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.streakRepaired,
      {'restored': restored},
    );
    return true;
  }

  // ----------------------------------------------------- archive / backfill

  /// Record an archive/backfill completion: fills the calendar (counts toward
  /// the monthly medal, visibly distinct) but never touches the streak.
  void recordArchiveCompletion({
    required String dateKey,
    int hintsUsed = 0,
    int stars = 3,
  }) {
    if (state.isCompleted(dateKey)) return;
    final results = Map<String, DailyResult>.from(state.results)
      ..[dateKey] = DailyResult(
        dateKey: dateKey,
        hintsUsed: hintsUsed,
        stars: stars,
        backfilled: true,
      );
    _save(state.copyWith(results: results));
  }

  // ------------------------------------------------------------- calendar

  /// Completions (live + backfilled) in 'YYYY-MM' [monthKey].
  int completionsInMonth(String monthKey) =>
      state.results.keys.where((k) => k.startsWith('$monthKey-')).length;

  /// The medal earned for [monthKey]. Gold needs every day of the month —
  /// for the current month that is only possible on its final day.
  MonthMedal medalForMonth(String monthKey) {
    final done = completionsInMonth(monthKey);
    if (done >= daysInMonth(monthKey)) return MonthMedal.gold;
    if (done >= 25) return MonthMedal.silver;
    if (done >= 20) return MonthMedal.bronze;
    return MonthMedal.none;
  }

  /// All months ('YYYY-MM', newest first) with at least one completion.
  List<String> get monthsWithResults {
    final months = <String>{
      for (final k in state.results.keys)
        if (k.length >= 7) k.substring(0, 7),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return months;
  }

  void _save(DailyRecord updated) {
    state = updated;
    ref.read(storageServiceProvider).saveDaily(updated);
  }
}

final dailyControllerProvider =
    NotifierProvider<DailyController, DailyRecord>(DailyController.new);
