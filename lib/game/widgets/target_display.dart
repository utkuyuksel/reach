import 'package:flutter/widgets.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';

/// The big "reach this number" target. A label is intentionally minimal; the
/// number itself in Fraunces is the focal point, with a short accent underline
/// echoing the prototype.
class TargetDisplay extends StatelessWidget {
  final int target;
  final GamePalette palette;

  /// Tiny iconographic label above the number (e.g. a small dot row). Kept
  /// language-independent.
  const TargetDisplay({
    super.key,
    required this.target,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A small triple-dot label: language-independent "target" marker.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: palette.inkSoft.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Animate the number when it changes (e.g. new puzzle).
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
          child: Text(
            '$target',
            key: ValueKey(target),
            style: AppText.fraunces(
              size: 66,
              weight: 600,
              color: palette.accent,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 46,
          height: 3,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
