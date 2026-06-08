import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'soft_button.dart';

/// The bottom controls: Undo, Restart, and Hint. Iconographic so the game
/// needs no localization. Free users see a small "watch ad" badge on Hint.
class ControlBar extends StatelessWidget {
  final GamePalette palette;
  final bool canUndo;
  final bool hintAvailable;
  final bool showAdBadge;
  final VoidCallback? onUndo;
  final VoidCallback onRestart;
  final VoidCallback? onHint;

  const ControlBar({
    super.key,
    required this.palette,
    required this.canUndo,
    required this.onRestart,
    required this.hintAvailable,
    required this.showAdBadge,
    this.onUndo,
    this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SoftButton(
          icon: Icons.undo_rounded,
          palette: palette,
          onTap: canUndo ? onUndo : null,
        ),
        const SizedBox(width: 10),
        SoftButton(
          icon: Icons.refresh_rounded,
          palette: palette,
          onTap: onRestart,
        ),
        const SizedBox(width: 10),
        SoftButton(
          icon: Icons.lightbulb_outline_rounded,
          palette: palette,
          onTap: hintAvailable ? onHint : null,
          badge: (showAdBadge && hintAvailable)
              ? _AdBadge(palette: palette)
              : null,
        ),
      ],
    );
  }
}

class _AdBadge extends StatelessWidget {
  final GamePalette palette;
  const _AdBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: palette.paper, width: 1.5),
      ),
      child: Icon(Icons.play_arrow_rounded, size: 11, color: Colors.white),
    );
  }
}

/// Board-clear progress: groups found vs total, with a calm progress bar.
class BoardProgress extends StatelessWidget {
  final GamePalette palette;
  final int found;
  final int total;

  const BoardProgress({
    super.key,
    required this.palette,
    required this.found,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (found / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$found / $total',
          style: AppText.mono(
            size: 12.5,
            weight: FontWeight.w500,
            color: palette.inkSoft,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                width: 180,
                height: 6,
                color: palette.line.withValues(alpha: 0.5),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                width: 180 * fraction,
                height: 6,
                color: palette.accent,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
