import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/palette.dart';

enum TileState { normal, path, match, hint, reject }

/// A single soft, tactile number tile. Pure visual — the board owns the drag
/// gesture. State is shown by colour AND shape/motion so it stays colourblind-
/// safe by default: path tiles lift, a match-ready trace always carries a ✓,
/// and a hint adds a ring. The [colorblind] setting makes the ✓ more prominent
/// and adds an ✕ to rejected traces (the warning state, otherwise colour-only).
class TileWidget extends StatelessWidget {
  final int value;
  final TileState state;
  final GamePalette palette;
  final double size;
  final bool colorblind;

  const TileWidget({
    super.key,
    required this.value,
    required this.state,
    required this.palette,
    required this.size,
    this.colorblind = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    final inPath = state == TileState.path || state == TileState.match;
    final lift = inPath ? -4.0 : 0.0;

    final (gradient, border, textColor, borderWidth, shadow) = _style();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      width: size,
      height: size,
      transform: Matrix4.translationValues(0, lift, 0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: shadow,
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '$value',
              style: AppText.fraunces(
                size: size * 0.40,
                weight: 600,
                color: textColor,
              ),
            ),
          ),
          // Match-ready: a ✓ so validity reads without relying on colour.
          // Always shown; the colourblind setting makes it more prominent.
          if (state == TileState.match)
            Positioned(
              top: 5,
              right: 6,
              child: Icon(
                Icons.check_rounded,
                size: colorblind ? 17 : 13,
                color: Colors.white,
              ),
            ),
          // Colourblind aid: mark the rejected/over state too — otherwise it is
          // distinguished from a normal tile only by its warning colour.
          if (state == TileState.reject && colorblind)
            Positioned(
              top: 5,
              right: 6,
              child: Icon(Icons.close_rounded, size: 17, color: palette.over),
            ),
        ],
      ),
    );
  }

  (List<Color>, Color, Color, double, List<BoxShadow>) _style() {
    switch (state) {
      case TileState.match:
        return (
          [palette.good, palette.goodDeep],
          palette.goodDeep,
          Colors.white,
          1.0,
          [
            BoxShadow(color: palette.goodDeep, offset: const Offset(0, 5)),
            BoxShadow(
              color: palette.good.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        );
      case TileState.path:
        return (
          [
            Color.lerp(palette.tile, palette.accent, 0.18)!,
            Color.lerp(palette.tileHi, palette.accent, 0.28)!,
          ],
          palette.accent,
          palette.accentDeep,
          2.0,
          [
            BoxShadow(color: palette.accentDeep, offset: const Offset(0, 5)),
            BoxShadow(
              color: palette.accentDeep.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 10),
              spreadRadius: -8,
            ),
          ],
        );
      case TileState.reject:
        return (
          [
            Color.lerp(palette.tile, palette.over, 0.18)!,
            Color.lerp(palette.tileHi, palette.over, 0.26)!,
          ],
          palette.over,
          palette.over,
          2.0,
          _resting(),
        );
      case TileState.hint:
        return (
          [palette.tile, palette.tileHi],
          palette.accent,
          palette.ink,
          2.5,
          _resting(),
        );
      case TileState.normal:
        return (
          [palette.tile, palette.tileHi],
          palette.tileEdge,
          palette.ink,
          1.0,
          _resting(),
        );
    }
  }

  List<BoxShadow> _resting() => [
        BoxShadow(color: palette.tileEdge, offset: const Offset(0, 5)),
        BoxShadow(
          color: palette.shadow,
          blurRadius: 18,
          offset: const Offset(0, 10),
          spreadRadius: -8,
        ),
      ];
}
