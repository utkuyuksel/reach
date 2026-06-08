import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_constants.dart';
import '../../util/date_key.dart';
import '../state/daily_controller.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../state/zen_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final daily = ref.watch(dailyControllerProvider);
    ref.watch(zenControllerProvider);
    final zenCtrl = ref.read(zenControllerProvider.notifier);

    final todayKey = dateKeyFor(DateTime.now());
    final todayDone = daily.isCompleted(todayKey);
    final level = zenCtrl.level;
    final cleared = ref.watch(zenControllerProvider).boardsCleared;

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SoftButton(
                      icon: Icons.tune_rounded,
                      palette: palette,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  kAppName,
                  style: AppText.fraunces(
                    size: 52,
                    weight: 600,
                    color: palette.ink,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kAppTagline.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppText.mono(
                    size: 10.5,
                    color: palette.inkSoft,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(flex: 2),
                _ModeCard(
                  palette: palette,
                  icon: Icons.calendar_today_rounded,
                  title: 'Daily',
                  trailing: todayDone
                      ? _Badge(
                          icon: Icons.check_rounded,
                          label: null,
                          palette: palette,
                          filled: true,
                        )
                      : null,
                  subtitle: daily.currentStreak > 0
                      ? _StreakRow(palette: palette, streak: daily.currentStreak)
                      : null,
                  onTap: () {
                    ref.read(gameControllerProvider.notifier).startDaily();
                    _openGame(context);
                  },
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  palette: palette,
                  icon: Icons.all_inclusive_rounded,
                  title: 'Zen',
                  trailing: _Badge(
                    icon: Icons.bolt_rounded,
                    label: '$level',
                    palette: palette,
                    filled: false,
                  ),
                  subtitle: _LevelProgress(
                    palette: palette,
                    cleared: cleared,
                  ),
                  onTap: () {
                    ref.read(gameControllerProvider.notifier).startZen();
                    _openGame(context);
                  },
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final GamePalette palette;
  final IconData icon;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ModeCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.tileEdge),
          boxShadow: [
            BoxShadow(color: palette.tileEdge, offset: const Offset(0, 5)),
            BoxShadow(
              color: palette.shadow,
              blurRadius: 22,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 26, color: palette.accent),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.fraunces(
                      size: 26,
                      weight: 600,
                      color: palette.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    subtitle!,
                  ],
                ],
              ),
            ),
            ?trailing,
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: palette.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _LevelProgress extends StatelessWidget {
  final GamePalette palette;
  final int cleared;

  const _LevelProgress({required this.palette, required this.cleared});

  @override
  Widget build(BuildContext context) {
    // Gentle "chapter" progress: fills over each stretch of 10 boards.
    final fraction = (cleared % 10) / 10.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Container(
                width: 130,
                height: 5,
                color: palette.line.withValues(alpha: 0.5),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 130 * (cleared == 0 ? 0.0 : (fraction == 0 ? 1.0 : fraction)),
                height: 5,
                color: palette.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$cleared cleared',
          style: AppText.mono(
            size: 11,
            color: palette.inkSoft,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _StreakRow extends StatelessWidget {
  final GamePalette palette;
  final int streak;
  const _StreakRow({required this.palette, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded,
            size: 14, color: palette.accent),
        const SizedBox(width: 5),
        Text(
          '$streak day streak',
          style: AppText.mono(
            size: 11.5,
            color: palette.inkSoft,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String? label;
  final GamePalette palette;
  final bool filled;

  const _Badge({
    required this.icon,
    required this.label,
    required this.palette,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : palette.accent;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label == null ? 7 : 9, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? palette.good : palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: AppText.mono(size: 12, weight: FontWeight.w500, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}
