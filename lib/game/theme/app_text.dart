import 'package:flutter/widgets.dart';

/// Typography helpers for the two bundled families:
///   * **Fraunces** (a variable serif) — the display face for the brand, the
///     big target number, and the numbers on tiles.
///   * **DM Mono** — small UI labels and meta text.
///
/// Fraunces is a variable font, so we drive its weight and optical size with
/// [FontVariation]s rather than [FontWeight] for precise control.
class AppText {
  AppText._();

  static const String frauncesFamily = 'Fraunces';
  static const String monoFamily = 'DM Mono';

  /// Fraunces with explicit weight + optical size.
  static TextStyle fraunces({
    required double size,
    double weight = 600,
    double opticalSize = 144,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: frauncesFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontVariations: [
        FontVariation('wght', weight),
        FontVariation('opsz', opticalSize),
      ],
    );
  }

  /// Numerals on TILES — the one surface where legibility beats brand
  /// typography. Fraunces' oldstyle serif digits (3/4/5 especially) read
  /// soft and ambiguous at tile sizes, so tiles use DM Mono: geometric,
  /// lining, tabular by design — the number-puzzle industry standard
  /// (Sudoku.com, Number Match). Fraunces stays on the big target number
  /// and titles, where the display cut shines.
  static TextStyle tileNumber({
    required double size,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  /// DM Mono for labels and meta text.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}
