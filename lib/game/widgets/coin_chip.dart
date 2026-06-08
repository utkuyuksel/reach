import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'pressable.dart';

/// A small coin-balance pill. The count animates when it changes (earning).
/// Tapping opens the shop (when wired). Hidden for Premium players, who don't
/// use coins.
class CoinChip extends StatelessWidget {
  final int coins;
  final GamePalette palette;
  final VoidCallback? onTap;

  /// Briefly tints the chip red — used to signal "not enough coins".
  final bool flash;

  const CoinChip({
    super.key,
    required this.coins,
    required this.palette,
    this.onTap,
    this.flash = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      depth: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: flash
              ? Color.lerp(palette.tile, palette.over, 0.35)
              : palette.tile,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: flash ? palette.over : palette.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_rounded, size: 16, color: palette.accent),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  axis: Axis.horizontal,
                  sizeFactor: anim,
                  child: child,
                ),
              ),
              child: Text(
                '$coins',
                key: ValueKey(coins),
                style: AppText.mono(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: palette.ink,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
