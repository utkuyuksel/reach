import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'soft_button.dart';

/// The calm board-complete overlay: a quiet "Cleared." with an efficiency star
/// rating, a "clean" badge (no hints), coins earned, and the next action.
class WinSheet extends StatelessWidget {
  final GamePalette palette;
  final int stars; // 1..3
  final bool clean; // no hints used
  final int coinsEarned;

  /// A short, language-light detail (e.g. streak or level). Optional.
  final Widget? detail;

  /// Zen chapter finished with this clear — show the quiet chest beat.
  final bool chapterComplete;

  /// One opt-in rewarded ad doubles this win's coins. Null hides the chip
  /// (Premium, or already doubled).
  final VoidCallback? onDouble;

  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final VoidCallback onHome;

  const WinSheet({
    super.key,
    required this.palette,
    required this.stars,
    required this.clean,
    required this.coinsEarned,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onHome,
    this.detail,
    this.chapterComplete = false,
    this.onDouble,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
      ),
      child: Container(
        color: palette.paper.withValues(alpha: 0.9),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WinPulse(color: palette.good),
            const SizedBox(height: 18),
            Text(
              'Cleared.',
              style: AppText.fraunces(
                size: 40,
                weight: 600,
                color: palette.good,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            _Stars(stars: stars, palette: palette),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on_rounded,
                    size: 17, color: palette.accent),
                const SizedBox(width: 6),
                Text(
                  '+$coinsEarned',
                  style: AppText.mono(
                    size: 14,
                    weight: FontWeight.w500,
                    color: palette.ink,
                    letterSpacing: 1,
                  ),
                ),
                if (clean) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.verified_rounded, size: 16, color: palette.good),
                  const SizedBox(width: 5),
                  Text(
                    'clean',
                    style: AppText.mono(
                      size: 12.5,
                      color: palette.good,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
            if (chapterComplete) ...[
              const SizedBox(height: 14),
              _ChapterChest(palette: palette),
            ],
            if (detail != null) ...[
              const SizedBox(height: 14),
              detail!,
            ],
            if (onDouble != null) ...[
              const SizedBox(height: 18),
              _DoubleChip(palette: palette, onTap: onDouble!),
            ],
            const SizedBox(height: 28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoftButton(
                  icon: Icons.home_outlined,
                  palette: palette,
                  onTap: onHome,
                ),
                const SizedBox(width: 10),
                SoftButton(
                  icon: primaryIcon,
                  palette: palette,
                  primary: true,
                  onTap: onPrimary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The quiet chapter-complete beat: a small chest icon scaling in.
class _ChapterChest extends StatelessWidget {
  final GamePalette palette;
  const _ChapterChest({required this.palette});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded,
                size: 18, color: palette.accent),
            const SizedBox(width: 7),
            Icon(Icons.check_rounded, size: 15, color: palette.accent),
          ],
        ),
      ),
    );
  }
}

/// Opt-in "watch an ad → double the coins" chip. Quiet, secondary, never
/// auto-prompted.
class _DoubleChip extends StatelessWidget {
  final GamePalette palette;
  final VoidCallback onTap;
  const _DoubleChip({required this.palette, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftButton(
      icon: Icons.play_circle_outline_rounded,
      label: '×2',
      palette: palette,
      onTap: onTap,
    );
  }
}

class _Stars extends StatelessWidget {
  final int stars;
  final GamePalette palette;
  const _Stars({required this.stars, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: filled ? 1 : 0.0),
            duration: Duration(milliseconds: 300 + i * 120),
            curve: Curves.easeOutBack,
            builder: (context, t, _) => Transform.scale(
              scale: filled ? (0.6 + 0.4 * t) : 1.0,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 34,
                color: filled
                    ? palette.accent
                    : palette.line.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WinPulse extends StatelessWidget {
  final Color color;
  const _WinPulse({required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t) * 0.5,
                child: Container(
                  width: 52 + 30 * t,
                  height: 52 + 30 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.check_rounded, color: color, size: 30),
              ),
            ],
          ),
        );
      },
    );
  }
}
