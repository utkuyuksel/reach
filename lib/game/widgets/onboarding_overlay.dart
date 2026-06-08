import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'soft_button.dart';
import 'tile_widget.dart';

/// A one-time, language-independent first-run tutorial: a looping animation of
/// a finger tracing three adjacent numbers (4 · 3 · 5) that add up to the
/// target (12), then clearing. No words — just numbers, a touch icon, and a ✓.
class OnboardingOverlay extends StatefulWidget {
  final GamePalette palette;
  final VoidCallback onDismiss;

  const OnboardingOverlay({
    super.key,
    required this.palette,
    required this.onDismiss,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _values = [4, 3, 5];
  static const _target = 12;
  static const _tile = 52.0;
  static const _gap = 10.0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Positioned.fill(
      child: Container(
        color: p.paper.withValues(alpha: 0.92),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: p.tile,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.tileEdge),
            boxShadow: [
              BoxShadow(
                color: p.shadow,
                blurRadius: 30,
                offset: const Offset(0, 16),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Target.
              Text(
                '$_target',
                style: AppText.fraunces(size: 44, weight: 600, color: p.accent),
              ),
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(top: 8, bottom: 28),
                decoration: BoxDecoration(
                  color: p.accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _demo(p, _c.value),
              ),
              const SizedBox(height: 30),
              SoftButton(
                icon: Icons.check_rounded,
                palette: p,
                primary: true,
                onTap: widget.onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demo(GamePalette p, double t) {
    // Phases: light tiles 1→2→3 (drag), then match (green + ✓), then reset.
    final matching = t >= 0.72;
    final lit = matching
        ? 3
        : t < 0.24
            ? 1
            : t < 0.48
                ? 2
                : 3;

    // Finger glides across the row during the drag, rests at the end on match.
    final stride = _tile + _gap;
    final progress = matching ? 1.0 : (t / 0.72).clamp(0.0, 1.0);
    final fingerX = progress * (stride * (_values.length - 1));

    return SizedBox(
      width: _tile * _values.length + _gap * (_values.length - 1),
      height: _tile + 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < _values.length; i++)
            Positioned(
              left: i * stride,
              top: 0,
              child: TileWidget(
                value: _values[i],
                state: i < lit
                    ? (matching ? TileState.match : TileState.path)
                    : TileState.normal,
                palette: p,
                size: _tile,
              ),
            ),
          // Touch indicator following the trace.
          Positioned(
            left: fingerX + _tile / 2 - 12,
            top: _tile - 6,
            child: Icon(Icons.touch_app_rounded, size: 24, color: p.accentDeep),
          ),
        ],
      ),
    );
  }
}
