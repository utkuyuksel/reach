import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_constants.dart';
import '../../engine/generator.dart';
import '../../util/date_key.dart';
import '../state/daily_controller.dart';
import '../state/entitlement_controller.dart';
import '../state/game_controller.dart';
import '../state/mosaic_controller.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../state/wallet_controller.dart';
import '../state/zen_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/coin_chip.dart';
import '../widgets/mosaic_view.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';
import 'badge_shelf_screen.dart';
import 'daily_calendar_screen.dart';
import 'game_screen.dart';
import 'mosaic_gallery_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _adBusy = false;

  void _openGame() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  }

  Future<void> _claimGift() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewardedAd();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned) {
      ref.read(walletControllerProvider.notifier).claimDailyGift();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final daily = ref.watch(dailyControllerProvider);
    final dailyCtrl = ref.read(dailyControllerProvider.notifier);
    ref.watch(zenControllerProvider);
    final zenCtrl = ref.read(zenControllerProvider.notifier);
    final premium = ref.watch(entitlementControllerProvider);
    final coins = ref.watch(walletControllerProvider);
    final wallet = ref.read(walletControllerProvider.notifier);

    final todayKey = dateKeyFor(DateTime.now());
    final todayDone = daily.isCompleted(todayKey);
    final chapter = zenCtrl.level;
    final cleared = ref.watch(zenControllerProvider).boardsCleared;
    final streak = dailyCtrl.effectiveStreak;
    final giftAvailable = !premium && wallet.giftAvailableToday;

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                // Status strip: economy + streak always present, ink-toned and
                // quiet — discoverability via presence, never via noise.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      CoinChip(
                        coins: coins,
                        palette: palette,
                        onTap: _openShop,
                      ),
                      const SizedBox(width: 8),
                      if (giftAvailable)
                        SoftButton(
                          icon: Icons.redeem_rounded,
                          palette: palette,
                          onTap: _adBusy ? null : _claimGift,
                        ),
                      const Spacer(),
                      SoftButton(
                        icon: Icons.workspace_premium_outlined,
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BadgeShelfScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SoftButton(
                        icon: Icons.tune_rounded,
                        palette: palette,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                    ],
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
                      : (streak > 0
                          ? _Badge(
                              icon: Icons.local_fire_department_rounded,
                              label: '$streak',
                              palette: palette,
                              filled: false,
                            )
                          : null),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WeekDots(palette: palette, daily: daily),
                      const SizedBox(height: 6),
                      if (todayDone)
                        _NextDailyCountdown(palette: palette)
                      else if (streak > 0)
                        _StreakRow(palette: palette, streak: streak),
                    ],
                  ),
                  onTap: () {
                    if (todayDone) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DailyCalendarScreen(),
                        ),
                      );
                    } else {
                      ref.read(gameControllerProvider.notifier).startDaily();
                      _openGame();
                    }
                  },
                  onLongPress: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DailyCalendarScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  palette: palette,
                  icon: Icons.all_inclusive_rounded,
                  title: 'Zen',
                  trailing: _Badge(
                    icon: Icons.bolt_rounded,
                    label: '$chapter',
                    palette: palette,
                    filled: false,
                  ),
                  subtitle: _LevelProgress(
                    palette: palette,
                    cleared: cleared,
                  ),
                  onTap: () {
                    ref.read(gameControllerProvider.notifier).startZen();
                    _openGame();
                  },
                  // Playtest shortcut, DEBUG BUILDS ONLY: long-press jumps
                  // +10 boards so late-chapter content is reachable fast.
                  onLongPress: kDebugMode
                      ? () => ref
                          .read(zenControllerProvider.notifier)
                          .debugAdvance(10)
                      : null,
                ),
                const SizedBox(height: 16),
                _MosaicCard(palette: palette),
                if (!premium) ...[
                  const SizedBox(height: 16),
                  _ShopRow(palette: palette, onTap: _openShop),
                ],
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Next puzzle in HH:MM" — the explicit come-back-tomorrow signal, shown on
/// the Daily card once today's board is done.
class _NextDailyCountdown extends StatefulWidget {
  final GamePalette palette;
  const _NextDailyCountdown({required this.palette});

  @override
  State<_NextDailyCountdown> createState() => _NextDailyCountdownState();
}

class _NextDailyCountdownState extends State<_NextDailyCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    var left = midnight.difference(now);
    if (left.isNegative) left = Duration.zero; // midnight race → 00:00
    final h = left.inHours.toString().padLeft(2, '0');
    final m = (left.inMinutes % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 14, color: widget.palette.inkSoft),
        const SizedBox(width: 5),
        Text(
          '$h:$m',
          style: AppText.mono(
            size: 11.5,
            color: widget.palette.inkSoft,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

/// The last seven days as quiet dots: filled = completed, ring = today,
/// faint = missed. The week's story at a glance, no words.
class _WeekDots extends StatelessWidget {
  final GamePalette palette;
  final dynamic daily; // DailyRecord

  const _WeekDots({required this.palette, required this.daily});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 6; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Builder(builder: (context) {
              final date = now.subtract(Duration(days: i));
              final done =
                  daily.isCompleted(dateKeyFor(date)) as bool;
              final isToday = i == 0;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? palette.accent : Colors.transparent,
                  border: done
                      ? null
                      : Border.all(
                          color: isToday
                              ? palette.accent
                              : palette.line,
                          width: isToday ? 1.5 : 1,
                        ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

/// The weekly mosaic event card: the slowly-appearing artwork IS the
/// progress display. Tap → the gallery.
class _MosaicCard extends ConsumerWidget {
  final GamePalette palette;
  const _MosaicCard({required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(mosaicControllerProvider.notifier);
    ref.watch(mosaicControllerProvider);
    final config = ref.read(gameConfigProvider);
    final revealed = ctrl.revealed;
    final weekKey = ctrl.currentWeekKey;

    // One-time teaching beat: the first time cells have appeared, the card
    // breathes twice so the player connects "my clears painted that".
    final settings = ref.watch(settingsControllerProvider);
    final introPulse = revealed > 0 && !settings.seenMosaicIntro;
    if (introPulse) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          ref.read(settingsControllerProvider.notifier).markMosaicIntroSeen());
    }

    Widget card = _card(context, ref, config, revealed, weekKey);
    if (introPulse) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeInOut,
        builder: (context, t, child) {
          // Two gentle breaths: scale follows |sin| of two periods.
          final breath =
              (0.5 - (t * 2 - (t * 2).floorToDouble() - 0.5).abs()) * 2;
          return Transform.scale(scale: 1 + 0.03 * breath, child: child);
        },
        child: card,
      );
    }
    return card;
  }

  Widget _card(BuildContext context, WidgetRef ref, dynamic config,
      int revealed, String weekKey) {
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MosaicGalleryScreen()),
      ),
      depth: 1.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: palette.tile,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.tileEdge),
        ),
        child: Row(
          children: [
            MosaicView(
              seed: Generator.dailySeed(dateFromKey(weekKey)),
              revealed: revealed,
              size: 52,
              palette: palette,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$revealed / ${config.mosaicSize}',
                    style: AppText.mono(
                      size: 12.5,
                      weight: FontWeight.w500,
                      color: palette.ink,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    revealed >= config.mosaicSize
                        ? Icons.check_circle_rounded
                        : Icons.auto_awesome_mosaic_rounded,
                    size: 14,
                    color: revealed >= config.mosaicSize
                        ? palette.good
                        : palette.inkSoft,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// Slim premium/shop entry — persistent presence, zero noise.
class _ShopRow extends StatelessWidget {
  final GamePalette palette;
  final VoidCallback onTap;
  const _ShopRow({required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1.5,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: palette.tile.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, size: 19, color: palette.inkSoft),
            const SizedBox(width: 12),
            Icon(Icons.block_rounded, size: 14, color: palette.inkSoft),
            const SizedBox(width: 4),
            Text('ads',
                style: AppText.mono(size: 11, color: palette.inkSoft)),
            const SizedBox(width: 12),
            Icon(Icons.lightbulb_outline_rounded,
                size: 14, color: palette.inkSoft),
            const SizedBox(width: 12),
            Icon(Icons.palette_outlined, size: 14, color: palette.inkSoft),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: palette.inkSoft),
          ],
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
  final VoidCallback? onLongPress;

  const _ModeCard({
    required this.palette,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
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
    // Chapter progress: fills over each stretch of 10 boards (in step with the
    // chapter badge — one chapter = 10 boards).
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
                width: 130 * fraction,
                height: 5,
                color: palette.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CH ${cleared ~/ 10 + 1} · ${cleared % 10}/10',
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
