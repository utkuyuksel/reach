import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';
import 'pressable.dart';

/// A calm, tactile button. Iconographic by default (language-independent), with
/// an optional short label. The [primary] variant uses the accent colour and a
/// "physical" bottom shadow, like the prototype's primary action.
class SoftButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool primary;
  final VoidCallback? onTap;
  final GamePalette palette;

  /// Optional small overlay badge (e.g. a "watch ad" marker on the hint).
  final Widget? badge;

  const SoftButton({
    super.key,
    required this.icon,
    required this.palette,
    this.label,
    this.primary = false,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = primary ? Colors.white : palette.ink;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: EdgeInsets.symmetric(
        horizontal: label == null ? 14 : 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: primary ? palette.accent : palette.tile,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: primary ? palette.accentDeep : palette.line,
        ),
        boxShadow: [
          if (primary && enabled)
            BoxShadow(
              color: palette.accentDeep,
              offset: const Offset(0, 4),
            ),
          if (!primary)
            BoxShadow(
              color: palette.shadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
              spreadRadius: -8,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label!,
              style: AppText.mono(
                size: 12.5,
                weight: FontWeight.w500,
                color: fg,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );

    return Pressable(
      onTap: onTap,
      depth: primary ? 3 : 1.5,
      child: badge == null
          ? content
          : Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                Positioned(top: -6, right: -6, child: badge!),
              ],
            ),
    );
  }
}
