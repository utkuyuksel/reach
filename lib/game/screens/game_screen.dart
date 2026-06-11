import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../engine/solver.dart';
import '../../services/analytics_service.dart';
import '../../services/sound_service.dart';
import '../state/daily_controller.dart';
import '../state/entitlement_controller.dart';
import '../state/game_controller.dart';
import '../state/game_session.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../state/stats_controller.dart';
import '../state/wallet_controller.dart';
import '../state/zen_controller.dart';
import '../theme/app_text.dart';
import '../theme/palette.dart';
import '../widgets/board_widget.dart';
import '../widgets/coin_chip.dart';
import '../widgets/control_bar.dart';
import '../widgets/paper_background.dart';
import '../widgets/soft_button.dart';
import '../widgets/target_display.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/win_sheet.dart';
import 'share_result_screen.dart';
import 'shop_screen.dart';

/// The core gameplay screen, driven by [gameControllerProvider].
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _adBusy = false;
  late final SoundService _sound;

  /// Seed of the board whose win reward was already doubled (one 2× per win).
  int? _doubledSeed;

  @override
  void initState() {
    super.initState();
    _sound = ref.read(soundServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(settingsControllerProvider).musicOn) {
        _sound.startAmbient();
      }
    });
  }

  @override
  void dispose() {
    _sound.stopAmbient();
    super.dispose();
  }

  void _haptic(VoidCallback fn) {
    if (ref.read(settingsControllerProvider).hapticsOn) fn();
  }

  void _sfx(void Function(SoundService s) fn) {
    if (ref.read(settingsControllerProvider).sfxOn) fn(_sound);
  }

  /// Returns true if the trace cleared a group (the board uses this to bounce
  /// a rejected trace).
  bool _onSubmit(List<int> path) {
    final before = ref.read(gameControllerProvider);
    final accepted =
        ref.read(gameControllerProvider.notifier).submitPath(path);
    final after = ref.read(gameControllerProvider);
    if (before == null || after == null) return accepted;
    if (after.isWon && !before.isWon) {
      _haptic(HapticFeedback.heavyImpact);
      _sfx((s) => s.win());
    } else if (after.found > before.found) {
      _haptic(HapticFeedback.mediumImpact);
      _sfx((s) => s.clear());
    } else if (!accepted && path.length >= 2) {
      _sfx((s) => s.invalid()); // wrong-sum trace
    }
    return accepted;
  }

  /// Hint flow, kept one-tap-simple. Premium: a daily allowance of free hints,
  /// then coins. Free players: coins if affordable, otherwise one rewarded ad
  /// grants the hint DIRECTLY (no coin detour) — so the player never manages
  /// coins to get help.
  Future<void> _onHint() async {
    if (_adBusy) return;
    final session = ref.read(gameControllerProvider);
    if (session == null || session.isWon) return;

    final analytics = ref.read(analyticsServiceProvider);
    analytics.log(AnalyticsEvents.hintRequested, {'mode': session.mode.name});

    // Guard: nothing to hint (shouldn't happen — the board stays solvable).
    if (Solver.hint(session.puzzle, session.state.grid) == null) {
      _toast('No groups left — undo a move.');
      return;
    }

    final config = ref.read(gameConfigProvider);

    if (ref.read(entitlementControllerProvider)) {
      final stats = ref.read(statsControllerProvider.notifier);
      if (stats.useFreeHint(config.premiumDailyFreeHints)) {
        ref.read(gameControllerProvider.notifier).revealHint();
        return;
      }
      // Premium allowance exhausted today → fall through to coins.
    }

    final wallet = ref.read(walletControllerProvider.notifier);
    if (wallet.trySpend(config.hintCost, reason: 'hint')) {
      ref.read(gameControllerProvider.notifier).revealHint();
      return;
    }

    // Not enough coins → one rewarded ad grants the hint directly.
    analytics.log(AnalyticsEvents.hintNoCoins);
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewardedAd();
    if (!mounted) return;
    setState(() => _adBusy = false);
    analytics.log(AnalyticsEvents.rewardedAdShown, {'earned': earned});
    if (!earned) return;
    ref.read(gameControllerProvider.notifier).revealHint();
  }

  Future<void> _onNext(GameSession session) async {
    if (session.mode != GameMode.zen) {
      _goHome();
      return;
    }
    final premium = ref.read(entitlementControllerProvider);
    final cleared = ref.read(zenControllerProvider).boardsCleared;
    final config = ref.read(gameConfigProvider);
    // Habit before monetization: no interstitial until the player is invested.
    if (!premium &&
        cleared >= config.firstInterstitialMinClears &&
        cleared % config.interstitialEveryNClears == 0) {
      await ref.read(adServiceProvider).showInterstitial();
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.interstitialShown);
      if (!mounted) return;
    }
    ref.read(gameControllerProvider.notifier).nextZen();
  }

  void _onShareDaily(GameSession session) {
    final daily = ref.read(dailyControllerProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareResultScreen(
          dateKey: session.dateKey ?? '',
          stars: ref.read(gameConfigProvider).starsForWrong(session.wrongTraces),
          groups: session.totalGroups,
          hintsUsed: session.hintsUsed,
          streak: daily.currentStreak,
        ),
      ),
    );
  }

  /// One rewarded ad doubles this win's coins (free players only).
  Future<void> _onDoubleCoins(GameSession session) async {
    if (_adBusy || _doubledSeed == session.puzzle.seed) return;
    setState(() => _adBusy = true);
    final earned = await ref.read(adServiceProvider).showRewardedAd();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (!earned) return;
    setState(() => _doubledSeed = session.puzzle.seed);
    final config = ref.read(gameConfigProvider);
    final bonus = session.coinsEarned * (config.winDoubleMultiplier - 1);
    ref
        .read(walletControllerProvider.notifier)
        .earn(bonus, reason: 'win_double');
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.winCoinsDoubled, {
      'bonus': bonus,
    });
  }

  void _goHome() => Navigator.of(context).maybePop();

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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    final palette = ref.watch(paletteProvider);
    final settings = ref.watch(settingsControllerProvider);
    final premium = ref.watch(entitlementControllerProvider);
    // Premium players don't use coins, so the chip is hidden for them.
    final coins = premium ? null : ref.watch(walletControllerProvider);

    // Start/stop the ambient pad when the music setting is toggled.
    ref.listen(settingsControllerProvider, (prev, next) {
      if (prev?.musicOn != next.musicOn) {
        if (next.musicOn) {
          _sound.startAmbient();
        } else {
          _sound.stopAmbient();
        }
      }
    });

    if (session == null) {
      return PaperBackground(palette: palette, child: const SizedBox.shrink());
    }

    final showOnboarding = !settings.onboardingDone && !session.isWon;

    return Scaffold(
      backgroundColor: palette.paper,
      body: PaperBackground(
        palette: palette,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(
                    palette: palette,
                    session: session,
                    onHome: _goHome,
                    coins: coins,
                  ),
                  const SizedBox(height: 8),
                  TargetDisplay(target: session.target, palette: palette),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: BoardWidget(
                        grid: session.state.grid,
                        target: session.target,
                        palette: palette,
                        colorblind: settings.colorblind,
                        hapticsEnabled: settings.hapticsOn,
                        hintCells: session.hintCells,
                        onTick: () => _sfx((s) => s.tap()),
                        onSubmitPath: _onSubmit,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BoardProgress(
                    palette: palette,
                    found: session.found,
                    total: session.totalGroups,
                  ),
                  const SizedBox(height: 16),
                  ControlBar(
                    palette: palette,
                    canUndo: session.state.canUndo && !session.isWon,
                    hintAvailable: !session.isWon,
                    showAdBadge: !premium,
                    onUndo: () {
                      _haptic(HapticFeedback.selectionClick);
                      ref.read(gameControllerProvider.notifier).undo();
                    },
                    onRestart: () {
                      _haptic(HapticFeedback.selectionClick);
                      ref.read(gameControllerProvider.notifier).restart();
                    },
                    onHint: _onHint,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
              if (session.stuck && !session.isWon && !showOnboarding)
                Positioned.fill(
                  child: _StuckOverlay(
                    palette: palette,
                    onUndo: () {
                      _haptic(HapticFeedback.selectionClick);
                      ref.read(gameControllerProvider.notifier).undo();
                    },
                    onRestart: () {
                      _haptic(HapticFeedback.selectionClick);
                      ref.read(gameControllerProvider.notifier).restart();
                    },
                  ),
                ),
              if (showOnboarding)
                TutorialOverlay(
                  palette: palette,
                  onComplete: () => ref
                      .read(settingsControllerProvider.notifier)
                      .setOnboardingDone(true),
                ),
              if (session.isWon)
                Positioned.fill(
                  child: WinSheet(
                    palette: palette,
                    stars: ref.read(gameConfigProvider)
                        .starsForWrong(session.wrongTraces),
                    clean: session.hintsUsed == 0,
                    coinsEarned: session.coinsEarned,
                    chapterComplete: _chapterJustCompleted(session),
                    detail: _winDetail(session, palette),
                    onDouble: !premium && _doubledSeed != session.puzzle.seed
                        ? () => _onDoubleCoins(session)
                        : null,
                    primaryIcon: switch (session.mode) {
                      GameMode.daily => Icons.ios_share_rounded,
                      GameMode.zen => Icons.arrow_forward_rounded,
                      GameMode.archive ||
                      GameMode.ladder =>
                        Icons.calendar_month_rounded,
                    },
                    onPrimary: () {
                      if (session.mode == GameMode.daily) {
                        _onShareDaily(session);
                      } else {
                        _onNext(session);
                      }
                    },
                    onHome: _goHome,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _chapterJustCompleted(GameSession session) =>
      session.mode == GameMode.zen &&
      session.isWon &&
      ref.read(zenControllerProvider).boardsCleared %
              Difficulty.clearsPerLevel ==
          0;

  Widget? _winDetail(GameSession session, GamePalette palette) {
    switch (session.mode) {
      case GameMode.daily:
        final streak = ref.read(dailyControllerProvider).currentStreak;
        if (streak <= 0) return null;
        return _DetailPill(
          icon: Icons.local_fire_department_rounded,
          text: '$streak',
          palette: palette,
        );
      case GameMode.archive:
        return _DetailPill(
          icon: Icons.calendar_month_rounded,
          text: session.dateKey ?? '',
          palette: palette,
        );
      case GameMode.ladder:
        return _DetailPill(
          icon: Icons.stairs_rounded,
          text: (session.dateKey ?? '').endsWith('#h') ? '6×6' : '4×4',
          palette: palette,
        );
      case GameMode.zen:
        final zen = ref.read(zenControllerProvider);
        final chapter = ref.read(zenControllerProvider.notifier).level;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailPill(
              icon: Icons.bolt_rounded,
              text: 'CH $chapter',
              palette: palette,
            ),
            if (zen.chain >= 2) ...[
              const SizedBox(width: 14),
              _DetailPill(
                icon: Icons.spa_rounded,
                text: '${zen.chain}',
                palette: palette,
              ),
            ],
          ],
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  final GamePalette palette;
  final GameSession session;
  final VoidCallback onHome;
  final int? coins;

  const _TopBar({
    required this.palette,
    required this.session,
    required this.onHome,
    this.coins,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData modeIcon, String modeLabel) = switch (session.mode) {
      GameMode.daily => (Icons.calendar_today_outlined, session.dateKey ?? ''),
      GameMode.archive =>
        (Icons.history_rounded, session.dateKey ?? ''),
      GameMode.ladder => (
          Icons.stairs_rounded,
          (session.dateKey ?? '').endsWith('#h') ? '6×6' : '4×4'
        ),
      GameMode.zen => (
          session.isFinale ? Icons.diamond_rounded : Icons.all_inclusive,
          'ZEN'
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          SoftButton(
            icon: Icons.home_outlined,
            palette: palette,
            onTap: onHome,
          ),
          const Spacer(),
          if (coins != null) ...[
            CoinChip(
              coins: coins!,
              palette: palette,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.tile,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  modeIcon,
                  size: 15,
                  color: session.isFinale && session.mode == GameMode.zen
                      ? palette.accent
                      : palette.inkSoft,
                ),
                const SizedBox(width: 8),
                Text(
                  modeLabel,
                  style: AppText.mono(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: palette.inkSoft,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A clear, gentle "no moves left" prompt shown only when the player has
/// genuinely run out of moves (peg-solitaire style). Not a fail screen — two
/// obvious ways forward: step back (Undo) or restart the board.
class _StuckOverlay extends StatelessWidget {
  final GamePalette palette;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  const _StuckOverlay({
    required this.palette,
    required this.onUndo,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, t, child) =>
          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      child: Container(
        color: palette.paper.withValues(alpha: 0.62),
        alignment: const Alignment(0, -0.15),
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
          decoration: BoxDecoration(
            color: palette.tile,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.tileEdge),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.block_rounded, size: 30, color: palette.accent),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoftButton(
                    icon: Icons.refresh_rounded,
                    palette: palette,
                    onTap: onRestart,
                  ),
                  const SizedBox(width: 12),
                  SoftButton(
                    icon: Icons.undo_rounded,
                    palette: palette,
                    primary: true,
                    onTap: onUndo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final GamePalette palette;

  const _DetailPill({
    required this.icon,
    required this.text,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: palette.accent),
        const SizedBox(width: 7),
        Text(
          text,
          style: AppText.mono(
            size: 13,
            weight: FontWeight.w500,
            color: palette.ink,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
