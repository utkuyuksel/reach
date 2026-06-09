import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/game_state.dart';
import '../../engine/models/puzzle.dart';
import '../../services/analytics_service.dart';
import '../../services/sound_service.dart';
import '../state/providers.dart';
import '../state/settings_controller.dart';
import '../theme/palette.dart';
import '../tutorial_puzzle.dart';
import 'board_widget.dart';
import 'soft_button.dart';
import 'target_display.dart';

/// The one-time interactive first-run tutorial. Instead of a passive animation,
/// the player SOLVES a tiny fixed board with real guided drags: the active row
/// is ringed and a finger glides along it, and the player performs the gesture
/// themselves — feeling the clear, then the win — before landing on their real
/// board. Fully wordless (numbers, rings, finger, ✓), and fully self-contained:
/// it runs its own [GameState] and never touches the live game controllers.
class TutorialOverlay extends ConsumerStatefulWidget {
  final GamePalette palette;

  /// Called when the tutorial is solved (or skipped). The caller marks
  /// onboarding done; the real board (already started) is then revealed.
  final VoidCallback onComplete;

  const TutorialOverlay({
    super.key,
    required this.palette,
    required this.onComplete,
  });

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  final Puzzle _puzzle = tutorialPuzzle();
  late GameState _state = GameState.fromPuzzle(_puzzle);
  bool _completing = false;

  /// The next group to trace: the first construction group still fully on the
  /// board. Robust to clear order (works even if the player clears the second
  /// row first). Empty once the board is won.
  List<int> get _activeGroup {
    if (_state.isWon) return const [];
    for (final group in _puzzle.groups) {
      if (group.every((i) => _state.grid.at(i) != null)) return group;
    }
    return const [];
  }

  void _sfx(void Function(SoundService s) play) {
    if (ref.read(settingsControllerProvider).sfxOn) {
      play(ref.read(soundServiceProvider));
    }
  }

  void _haptic(VoidCallback fn) {
    if (ref.read(settingsControllerProvider).hapticsOn) fn();
  }

  bool _onSubmit(List<int> path) {
    final next = _state.submitPath(path);
    if (identical(next, _state)) {
      if (path.length >= 2) _sfx((s) => s.invalid());
      return false; // BoardWidget bounces the rejected trace
    }
    setState(() => _state = next);
    if (next.isWon) {
      _haptic(HapticFeedback.heavyImpact);
      _sfx((s) => s.win());
      _finish();
    } else {
      _haptic(HapticFeedback.mediumImpact);
      _sfx((s) => s.clear());
    }
    return true;
  }

  void _finish() {
    if (_completing) return;
    _completing = true;
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.onboardingCompleted);
    // Let the win ✓ land before handing off to the real board.
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onComplete();
    });
  }

  void _skip() {
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.onboardingSkipped);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final settings = ref.watch(settingsControllerProvider);
    final active = _activeGroup;

    return Positioned.fill(
      child: Container(
        color: p.paper,
        child: SafeArea(
          child: Column(
            children: [
              // Low-emphasis, wordless skip for returning players.
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: SoftButton(
                    icon: Icons.close_rounded,
                    palette: p,
                    onTap: _skip,
                  ),
                ),
              ),
              const Spacer(),
              TargetDisplay(target: _puzzle.target, palette: p),
              const SizedBox(height: 28),
              SizedBox(
                height: 230,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: BoardWidget(
                    grid: _state.grid,
                    target: _puzzle.target,
                    palette: p,
                    colorblind: settings.colorblind,
                    hapticsEnabled: settings.hapticsOn,
                    hintCells: active,
                    coachPath: active,
                    onTick: () => _sfx((s) => s.tap()),
                    onSubmitPath: _onSubmit,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Win celebration: a single ✓ that scales in.
              SizedBox(
                height: 56,
                child: _state.isWon
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) => Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.scale(scale: t, child: child),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 48,
                          color: p.good,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
