import 'package:flutter/widgets.dart';

/// A complete, calm colour palette for the game. The default ("Clay") matches
/// the prototype's terracotta-on-paper look. Additional palettes are cosmetic
/// and unlock with Premium.
///
/// State colours (selected / rejected / match) are part of the palette, but the
/// UI never relies on colour ALONE to convey state — it also lifts the tile
/// (selected) and draws an icon badge (✓ on a match) — so the game stays
/// colourblind-safe. The Settings "colourblind" toggle makes the ✓ more
/// prominent and adds an ✕ to rejected traces.
@immutable
class GamePalette {
  final String id;
  final String name;

  /// Coins to unlock this palette (0 = free). Premium unlocks all paid palettes.
  final int coinPrice;

  // Surfaces
  final Color paper; // background base
  final Color paperHi; // background highlight (top of radial gradient)
  final Color paperLo; // background shade (bottom)

  // Text / ink
  final Color ink;
  final Color inkSoft;

  // Accent (primary)
  final Color accent;
  final Color accentDeep;

  // Tiles
  final Color tile;
  final Color tileHi; // bottom of the tile's vertical gradient
  final Color tileEdge;

  // Match — deliberately distinct from [accent] so a match-ready trace never
  // reads like an in-progress selection.
  final Color good;
  final Color goodDeep;

  // Rejected / "wrong" trace
  final Color over;

  final Color line;
  final Color shadow;

  const GamePalette({
    required this.id,
    required this.name,
    this.coinPrice = 0,
    required this.paper,
    required this.paperHi,
    required this.paperLo,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.accentDeep,
    required this.tile,
    required this.tileHi,
    required this.tileEdge,
    required this.good,
    required this.goodDeep,
    required this.over,
    required this.line,
    required this.shadow,
  });

  /// Free palettes (the default) need no unlock.
  bool get isFree => coinPrice == 0;

  static const GamePalette clay = GamePalette(
    id: 'clay',
    name: 'Clay',
    coinPrice: 0,
    paper: Color(0xFFF5EFE2),
    paperHi: Color(0xFFFAF5EA),
    paperLo: Color(0xFFEFE7D6),
    ink: Color(0xFF26221C),
    inkSoft: Color(0xFF6B6253),
    accent: Color(0xFFC9622E),
    accentDeep: Color(0xFFA44C1F),
    tile: Color(0xFFFBF7EE),
    tileHi: Color(0xFFF3ECDC),
    tileEdge: Color(0xFFE4DAC3),
    good: Color(0xFF3F7D54),
    goodDeep: Color(0xFF356A47),
    over: Color(0xFFB54A3A),
    line: Color(0xFFDED3BB),
    shadow: Color(0x2E3C301E),
  );

  static const GamePalette sage = GamePalette(
    id: 'sage',
    name: 'Sage',
    coinPrice: 150,
    paper: Color(0xFFEEF1E7),
    paperHi: Color(0xFFF4F6EE),
    paperLo: Color(0xFFE3E8D7),
    ink: Color(0xFF24291F),
    inkSoft: Color(0xFF626A56),
    accent: Color(0xFF5E8A5A),
    accentDeep: Color(0xFF456F40),
    tile: Color(0xFFF7F9F1),
    tileHi: Color(0xFFEDF0E2),
    tileEdge: Color(0xFFD6DCC6),
    good: Color(0xFF2F6F7D), // teal — distinct from the green accent
    goodDeep: Color(0xFF255B66),
    over: Color(0xFFB06A2E),
    line: Color(0xFFD3D9C5),
    shadow: Color(0x2E2A3018),
  );

  static const GamePalette dusk = GamePalette(
    id: 'dusk',
    name: 'Dusk',
    coinPrice: 250,
    paper: Color(0xFFE9E6F0),
    paperHi: Color(0xFFF1EFF7),
    paperLo: Color(0xFFDED9EC),
    ink: Color(0xFF272332),
    inkSoft: Color(0xFF615A75),
    accent: Color(0xFF6D5D9C),
    accentDeep: Color(0xFF50447A),
    tile: Color(0xFFF4F2FA),
    tileHi: Color(0xFFEBE7F4),
    tileEdge: Color(0xFFD7D1E5),
    good: Color(0xFF3F7D6E), // teal-green
    goodDeep: Color(0xFF316257),
    over: Color(0xFFB05673),
    line: Color(0xFFD8D2E4),
    shadow: Color(0x2E241E33),
  );

  static const GamePalette noir = GamePalette(
    id: 'ink',
    name: 'Ink',
    coinPrice: 400,
    paper: Color(0xFFECEBE6),
    paperHi: Color(0xFFF4F3EF),
    paperLo: Color(0xFFE0DFD8),
    ink: Color(0xFF222220),
    inkSoft: Color(0xFF67665F),
    accent: Color(0xFF54514B),
    accentDeep: Color(0xFF35332E),
    tile: Color(0xFFF6F5F1),
    tileHi: Color(0xFFECEBE5),
    tileEdge: Color(0xFFD6D5CC),
    good: Color(0xFF2E6F58), // the lone hint of colour, reinforced by the ✓
    goodDeep: Color(0xFF235646),
    over: Color(0xFF8A4A3E),
    line: Color(0xFFD7D6CD),
    shadow: Color(0x2E2A2A24),
  );

  static const List<GamePalette> all = [clay, sage, dusk, noir];

  static GamePalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => clay);
}
