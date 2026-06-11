import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_constants.dart';
import '../../util/date_key.dart';
import '../state/daily_controller.dart';
import '../state/entitlement_controller.dart';
import '../state/game_controller.dart';
import '../state/providers.dart';
import '../state/wallet_controller.dart';
import '../state/zen_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/coin_chip.dart';
import '../widgets/paper_background.dart';
import '../widgets/pressable.dart';
import '../widgets/soft_button.dart';
import 'badge_shelf_screen.dart';
import 'daily_calendar_screen.dart';
import 'game_screen.dart';
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
                  subtitle: todayDone
                      ? _NextDailyCountdown(palette: palette)
                      : (streak > 0
                          ? _StreakRow(palette: palette, streak: streak)
                          : null),
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
                ),
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
    final left = midnight.difference(now);
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
