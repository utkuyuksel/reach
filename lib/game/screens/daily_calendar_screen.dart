import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../util/date_key.dart';
import '../state/daily_controller.dart';
import '../state/entitlement_controller.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../state/wallet_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/coin_chip.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';
import 'game_screen.dart';

/// The Daily calendar: a month grid of results, monthly-medal progress, the
/// trophy shelf, streak protection (Freeze tokens + the quiet Repair offer),
/// and archive/backfill entry for missed days. The Sudoku.com retention
/// skeleton, rendered calm and wordless.
class DailyCalendarScreen extends ConsumerStatefulWidget {
  const DailyCalendarScreen({super.key});

  @override
  ConsumerState<DailyCalendarScreen> createState() =>
      _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends ConsumerState<DailyCalendarScreen> {
  /// First day of the displayed month.
  late DateTime _month;

  /// The earliest month the calendar navigates to (the Daily epoch).
  static final DateTime _epoch = DateTime(2026, 1, 1);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.calendarOpened);
  }

  bool get _canGoBack =>
      DateTime(_month.year, _month.month - 1, 1).isAfter(
        _epoch.subtract(const Duration(days: 1)),
      );

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.year != now.year || _month.month != now.month;
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  void _haptic() {
    if (ref.read(settingsControllerProvider).hapticsOn) {
      HapticFeedback.selectionClick();
    }
  }

  void _toast(String message) {
    final palette = ref.read(paletteProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppText.mono(size: 12.5, color: Colors.white)),
        backgroundColor: palette.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openBoard(DateTime date, {required bool isToday}) {
    final controller = ref.read(gameControllerProvider.notifier);
    if (isToday) {
      controller.startDaily();
    } else {
      controller.startArchive(date);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  /// Tap on a past, uncompleted day: archive access rules + backfill price.
  Future<void> _onMissedDay(DateTime date) async {
    final premium = ref.read(entitlementControllerProvider);
    final config = ref.read(gameConfigProvider);
    final daysAgo = daysBetween(date, DateTime.now());
    if (!premium && daysAgo > config.freeArchiveDays) {
      _toast('Premium unlocks the full archive.');
      return;
    }
    final palette = ref.read(paletteProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: palette.ink.withValues(alpha: 0.35),
      builder: (context) => _BackfillDialog(
        palette: palette,
        cost: config.backfillCost,
        dateKey: dateKeyFor(date),
      ),
    );
    if (confirmed != true || !mounted) return;
    final wallet = ref.read(walletControllerProvider.notifier);
    if (!wallet.trySpend(config.backfillCost, reason: 'backfill')) {
      _toast('Not enough coins.');
      return;
    }
    _haptic();
    _openBoard(date, isToday: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final daily = ref.watch(dailyControllerProvider);
    final dailyCtrl = ref.read(dailyControllerProvider.notifier);
    final config = ref.read(gameConfigProvider);
    final coins = ref.watch(walletControllerProvider);

    final monthKey = monthKeyFor(_month);
    final done = dailyCtrl.completionsInMonth(monthKey);
    final medal = dailyCtrl.medalForMonth(monthKey);
    final streak = dailyCtrl.effectiveStreak;

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    SoftButton(
                      icon: Icons.arrow_back_rounded,
                      palette: palette,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_month_rounded,
                        size: 26, color: palette.ink),
                    const Spacer(),
                    CoinChip(coins: coins, palette: palette),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    // Streak + protection row.
                    _StreakCard(
                      palette: palette,
                      streak: streak,
                      longest: daily.longestStreak,
                      freezeTokens: daily.freezeTokens,
                      maxTokens: config.maxFreezeTokens,
                      freezeCost: config.streakFreezeCost,
                      onBuyFreeze: () {
                        if (ref
                            .read(dailyControllerProvider.notifier)
                            .buyFreezeToken()) {
                          _haptic();
                          ref.read(analyticsServiceProvider).log(
                              AnalyticsEvents.streakFreezeBought);
                        } else {
                          _toast('Not enough coins.');
                        }
                      },
                    ),
                    if (dailyCtrl.repairAvailable) ...[
                      const SizedBox(height: 12),
                      _RepairCard(
                        palette: palette,
                        brokenStreak: daily.brokenStreak,
                        cost: config.streakRepairCost,
                        onRepair: () {
                          if (ref
                              .read(dailyControllerProvider.notifier)
                              .repairStreak()) {
                            _haptic();
                          } else {
                            _toast('Not enough coins.');
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    // Month header with navigation.
                    Row(
                      children: [
                        SoftButton(
                          icon: Icons.chevron_left_rounded,
                          palette: palette,
                          onTap: _canGoBack ? () => _shiftMonth(-1) : null,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_month.year} · ${_month.month.toString().padLeft(2, '0')}',
                              style: AppText.mono(
                                size: 14,
                                weight: FontWeight.w500,
                                color: palette.ink,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                        SoftButton(
                          icon: Icons.chevron_right_rounded,
                          palette: palette,
                          onTap: _canGoForward ? () => _shiftMonth(1) : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MonthGrid(
                      palette: palette,
                      month: _month,
                      daily: daily,
                      onToday: () => _openBoard(DateTime.now(), isToday: true),
                      onMissed: _onMissedDay,
                    ),
                    const SizedBox(height: 18),
                    // Medal progress for the displayed month.
                    _MedalProgress(
                      palette: palette,
                      done: done,
                      total: daysInMonth(monthKey),
                      medal: medal,
                    ),
                    const SizedBox(height: 26),
                    // Trophy shelf (months with any medal).
                    _TrophyShelf(palette: palette, dailyCtrl: dailyCtrl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final GamePalette palette;
  final int streak;
  final int longest;
  final int freezeTokens;
  final int maxTokens;
  final int freezeCost;
  final VoidCallback onBuyFreeze;

  const _StreakCard({
    required this.palette,
    required this.streak,
    required this.longest,
    required this.freezeTokens,
    required this.maxTokens,
    required this.freezeCost,
    required this.onBuyFreeze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.tileEdge),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 22,
            color: streak > 0 ? palette.accent : palette.line,
          ),
          const SizedBox(width: 8),
          Text(
            '$streak',
            style: AppText.fraunces(
                size: 24, weight: 600, color: palette.ink),
          ),
          const SizedBox(width: 14),
          Text(
            'best $longest',
            style: AppText.mono(
                size: 11, color: palette.inkSoft, letterSpacing: 1),
          ),
          const Spacer(),
          // Freeze tokens: filled/empty snowflakes + buy.
          for (var i = 0; i < maxTokens; i++)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Icon(
                Icons.ac_unit_rounded,
                size: 17,
                color: i < freezeTokens
                    ? palette.accent
                    : palette.line.withValues(alpha: 0.8),
              ),
            ),
          if (freezeTokens < maxTokens) ...[
            const SizedBox(width: 4),
            Pressable(
              onTap: onBuyFreeze,
              depth: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 13, color: palette.accent),
                    Icon(Icons.monetization_on_rounded,
                        size: 12, color: palette.accent),
                    const SizedBox(width: 2),
                    Text(
                      '$freezeCost',
                      style: AppText.mono(
                          size: 11,
                          weight: FontWeight.w500,
                          color: palette.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The once-per-month, quiet streak-repair offer. Lives only here on the
/// calendar — never a popup.
class _RepairCard extends StatelessWidget {
  final GamePalette palette;
  final int brokenStreak;
  final int cost;
  final VoidCallback onRepair;

  const _RepairCard({
    required this.palette,
    required this.brokenStreak,
    required this.cost,
    required this.onRepair,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.healing_rounded, size: 20, color: palette.accent),
          const SizedBox(width: 10),
          Icon(Icons.local_fire_department_rounded,
              size: 16, color: palette.inkSoft),
          const SizedBox(width: 4),
          Text(
            '$brokenStreak',
            style: AppText.mono(
                size: 13, weight: FontWeight.w500, color: palette.ink),
          ),
          const Spacer(),
          SoftButton(
            icon: Icons.monetization_on_rounded,
            label: '$cost',
            palette: palette,
            primary: true,
            onTap: onRepair,
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  final GamePalette palette;
  final DateTime month;
  final dynamic daily; // DailyRecord
  final VoidCallback onToday;
  final void Function(DateTime) onMissed;

  const _MonthGrid({
    required this.palette,
    required this.month,
    required this.daily,
    required this.onToday,
    required this.onMissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = daysInMonth(monthKeyFor(month));
    // Monday-first column for the 1st of the month.
    final leading = (month.weekday - 1) % 7;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= days; d++) {
      final date = DateTime(month.year, month.month, d);
      final key = dateKeyFor(date);
      final result = daily.resultFor(key);
      final isToday = date == today;
      final isFuture = date.isAfter(today);

      cells.add(_DayCell(
        palette: palette,
        day: d,
        result: result,
        isToday: isToday,
        isFuture: isFuture,
        onTap: result != null || isFuture
            ? null
            : (isToday ? onToday : () => onMissed(date)),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  final GamePalette palette;
  final int day;
  final dynamic result; // DailyResult?
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  const _DayCell({
    required this.palette,
    required this.day,
    required this.result,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = result != null;
    final backfilled = done && (result.backfilled as bool);
    final threeStar = done && (result.stars as int) >= 3;

    final Color bg;
    final Color fg;
    Border? border;
    if (done) {
      bg = backfilled
          ? palette.accent.withValues(alpha: 0.35)
          : palette.accent;
      fg = backfilled ? palette.ink : Colors.white;
      if (threeStar && !backfilled) {
        border = Border.all(color: palette.good, width: 2);
      }
    } else if (isToday) {
      bg = palette.tile;
      fg = palette.ink;
      border = Border.all(color: palette.accent, width: 2);
    } else if (isFuture) {
      bg = palette.tile.withValues(alpha: 0.4);
      fg = palette.line;
    } else {
      bg = palette.tile;
      fg = palette.inkSoft;
      border = Border.all(color: palette.tileEdge);
    }

    return Pressable(
      onTap: onTap,
      depth: 1,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: AppText.mono(
            size: 12,
            weight: done ? FontWeight.w500 : FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _MedalProgress extends StatelessWidget {
  final GamePalette palette;
  final int done;
  final int total;
  final MonthMedal medal;

  const _MedalProgress({
    required this.palette,
    required this.done,
    required this.total,
    required this.medal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.tileEdge),
      ),
      child: Row(
        children: [
          _MedalIcon(palette: palette, medal: medal, size: 26),
          const SizedBox(width: 12),
          Text(
            '$done / $total',
            style: AppText.mono(
              size: 13,
              weight: FontWeight.w500,
              color: palette.ink,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          // Threshold marks: bronze 20 · silver 25 · gold all.
          Text(
            '20 · 25 · $total',
            style: AppText.mono(
                size: 10.5, color: palette.inkSoft, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _MedalIcon extends StatelessWidget {
  final GamePalette palette;
  final MonthMedal medal;
  final double size;

  const _MedalIcon({
    required this.palette,
    required this.medal,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (medal) {
      MonthMedal.gold => palette.accent,
      MonthMedal.silver => palette.inkSoft,
      MonthMedal.bronze => palette.accentDeep,
      MonthMedal.none => palette.line,
    };
    return Icon(Icons.workspace_premium_rounded, size: size, color: color);
  }
}

class _TrophyShelf extends StatelessWidget {
  final GamePalette palette;
  final DailyController dailyCtrl;

  const _TrophyShelf({required this.palette, required this.dailyCtrl});

  @override
  Widget build(BuildContext context) {
    final monthsWithMedals = dailyCtrl.monthsWithResults
        .where((m) => dailyCtrl.medalForMonth(m) != MonthMedal.none)
        .toList();
    if (monthsWithMedals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final m in monthsWithMedals)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.tile,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.tileEdge),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MedalIcon(
                  palette: palette,
                  medal: dailyCtrl.medalForMonth(m),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  m,
                  style: AppText.mono(
                      size: 11, color: palette.inkSoft, letterSpacing: 1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Wordless backfill confirm: coin cost → play that day's board.
class _BackfillDialog extends StatelessWidget {
  final GamePalette palette;
  final int cost;
  final String dateKey;

  const _BackfillDialog({
    required this.palette,
    required this.cost,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 30,
              offset: const Offset(0, 16),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 30, color: palette.accent),
            const SizedBox(height: 10),
            Text(
              dateKey,
              style: AppText.mono(
                  size: 13, color: palette.inkSoft, letterSpacing: 1.5),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftButton(
                  icon: Icons.close_rounded,
                  palette: palette,
                  onTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                SoftButton(
                  icon: Icons.monetization_on_rounded,
                  label: '$cost',
                  palette: palette,
                  primary: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
