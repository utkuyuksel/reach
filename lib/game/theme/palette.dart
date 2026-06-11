import 'package:flutter/widgets.dart';

/// A complete, calm colour palette for the game. The default ("Clay") matches
/// the prototype's terracotta-on-paper look. Additional palettes are cosmetic:
/// coin-priced (Premium unlocks those), or exclusive (Starter Pack only).
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

  /// Coins to unlock this palette (0 = free). Premium unlocks all coin-priced
  /// palettes.
  final int coinPrice;

  /// Exclusive palettes can NEVER be bought with coins and are not part of
  /// Premium — they are granted (e.g. by the Starter Pack) and exist so a
  /// purchase can carry value no grind replicates.
  final bool exclusive;

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
    this.exclusive = false,
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

  /// Free for everyone (the default palette).
  bool get isFree => coinPrice == 0 && !exclusive;

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

  static const GamePalette tide = GamePalette(
    id: 'tide',
    name: 'Tide',
    coinPrice: 600,
    paper: Color(0xFFE5EEEE),
    paperHi: Color(0xFFEFF5F5),
    paperLo: Color(0xFFD9E6E6),
    ink: Color(0xFF1F2B2D),
    inkSoft: Color(0xFF587073),
    accent: Color(0xFF35808C),
    accentDeep: Color(0xFF26646F),
    tile: Color(0xFFF3F8F8),
    tileHi: Color(0xFFE7F0F0),
    tileEdge: Color(0xFFCFDFDF),
    good: Color(0xFF4F7D44), // kelp green, distinct from the teal accent
    goodDeep: Color(0xFF3F6536),
    over: Color(0xFFB06148),
    line: Color(0xFFCCDCDC),
    shadow: Color(0x2E1E3234),
  );

  static const GamePalette honey = GamePalette(
    id: 'honey',
    name: 'Honey',
    coinPrice: 600,
    paper: Color(0xFFF6EFDC),
    paperHi: Color(0xFFFBF5E6),
    paperLo: Color(0xFFF0E6CC),
    ink: Color(0xFF2B2415),
    inkSoft: Color(0xFF73664A),
    accent: Color(0xFFB8862B),
    accentDeep: Color(0xFF936A1D),
    tile: Color(0xFFFCF7E8),
    tileHi: Color(0xFFF4ECD4),
    tileEdge: Color(0xFFE6D9B7),
    good: Color(0xFF49764C),
    goodDeep: Color(0xFF3A613D),
    over: Color(0xFFB14F33),
    line: Color(0xFFE0D3AE),
    shadow: Color(0x2E3A2F15),
  );

  static const GamePalette rosewood = GamePalette(
    id: 'rosewood',
    name: 'Rosewood',
    coinPrice: 800,
    paper: Color(0xFFF3E8E6),
    paperHi: Color(0xFFF8F0EE),
    paperLo: Color(0xFFEBDCD9),
    ink: Color(0xFF2D2122),
    inkSoft: Color(0xFF755F60),
    accent: Color(0xFFA15858),
    accentDeep: Color(0xFF814242),
    tile: Color(0xFFFAF2F0),
    tileHi: Color(0xFFF1E4E1),
    tileEdge: Color(0xFFE1CDC9),
    good: Color(0xFF3D7468),
    goodDeep: Color(0xFF2F5C52),
    over: Color(0xFF9C6A2C),
    line: Color(0xFFDFCBC7),
    shadow: Color(0x2E33211F),
  );

  static const GamePalette moss = GamePalette(
    id: 'moss',
    name: 'Moss',
    coinPrice: 800,
    paper: Color(0xFFEAECDF),
    paperHi: Color(0xFFF2F3E9),
    paperLo: Color(0xFFDFE2CF),
    ink: Color(0xFF22271B),
    inkSoft: Color(0xFF656C52),
    accent: Color(0xFF6F7E36),
    accentDeep: Color(0xFF566327),
    tile: Color(0xFFF4F6EC),
    tileHi: Color(0xFFE9ECDA),
    tileEdge: Color(0xFFD3D8BD),
    good: Color(0xFF35707F), // water-teal against the olive accent
    goodDeep: Color(0xFF295A67),
    over: Color(0xFFAD5B35),
    line: Color(0xFFD0D5BB),
    shadow: Color(0x2E282E16),
  );

  static const GamePalette sand = GamePalette(
    id: 'sand',
    name: 'Sand',
    coinPrice: 1000,
    paper: Color(0xFFF1E8D8),
    paperHi: Color(0xFFF7F0E2),
    paperLo: Color(0xFFE8DCC6),
    ink: Color(0xFF2A2318),
    inkSoft: Color(0xFF71644E),
    accent: Color(0xFF9C6B3F),
    accentDeep: Color(0xFF7C522D),
    tile: Color(0xFFF9F2E4),
    tileHi: Color(0xFFEFE5D0),
    tileEdge: Color(0xFFDFD0B2),
    good: Color(0xFF40704F),
    goodDeep: Color(0xFF335B40),
    over: Color(0xFFAA4938),
    line: Color(0xFFDACBAB),
    shadow: Color(0x2E362B16),
  );

  static const GamePalette plum = GamePalette(
    id: 'plum',
    name: 'Plum',
    coinPrice: 1000,
    paper: Color(0xFFEFE6EC),
    paperHi: Color(0xFFF5EEF3),
    paperLo: Color(0xFFE5D8E1),
    ink: Color(0xFF2B2027),
    inkSoft: Color(0xFF6F5C68),
    accent: Color(0xFF82486B),
    accentDeep: Color(0xFF663452),
    tile: Color(0xFFF7F0F4),
    tileHi: Color(0xFFEDE1E8),
    tileEdge: Color(0xFFDCC9D5),
    good: Color(0xFF3E7560),
    goodDeep: Color(0xFF305D4C),
    over: Color(0xFFA85E3B),
    line: Color(0xFFD9C7D2),
    shadow: Color(0x2E2E1D28),
  );

  static const GamePalette slate = GamePalette(
    id: 'slate',
    name: 'Slate',
    coinPrice: 1200,
    paper: Color(0xFFE7EAEF),
    paperHi: Color(0xFFEFF2F6),
    paperLo: Color(0xFFDBE0E8),
    ink: Color(0xFF20242B),
    inkSoft: Color(0xFF5D6776),
    accent: Color(0xFF53688E),
    accentDeep: Color(0xFF3E5072),
    tile: Color(0xFFF3F5F9),
    tileHi: Color(0xFFE8ECF2),
    tileEdge: Color(0xFFD2D9E3),
    good: Color(0xFF477551),
    goodDeep: Color(0xFF395F42),
    over: Color(0xFFAC5847),
    line: Color(0xFFD0D7E0),
    shadow: Color(0x2E1F2733),
  );

  /// The first dark palette — the catalogue's flagship.
  static const GamePalette midnight = GamePalette(
    id: 'midnight',
    name: 'Midnight',
    coinPrice: 1200,
    paper: Color(0xFF23272F),
    paperHi: Color(0xFF2A2F39),
    paperLo: Color(0xFF1C2027),
    ink: Color(0xFFEDE7DA),
    inkSoft: Color(0xFF9BA0AB),
    accent: Color(0xFFD9A05B),
    accentDeep: Color(0xFFB7813F),
    tile: Color(0xFF2F3540),
    tileHi: Color(0xFF272D37),
    tileEdge: Color(0xFF1A1E25),
    good: Color(0xFF5FA47C),
    goodDeep: Color(0xFF4A8763),
    over: Color(0xFFC2685A),
    line: Color(0xFF3A414D),
    shadow: Color(0x66101318),
  );

  /// Starter Pack exclusive: warm darkness with an ember glow. Never sold for
  /// coins, never part of Premium.
  static const GamePalette ember = GamePalette(
    id: 'ember',
    name: 'Ember',
    coinPrice: 0,
    exclusive: true,
    paper: Color(0xFF2B2320),
    paperHi: Color(0xFF332A26),
    paperLo: Color(0xFF231C19),
    ink: Color(0xFFF2E6D8),
    inkSoft: Color(0xFFA6968A),
    accent: Color(0xFFE2703D),
    accentDeep: Color(0xFFBE5527),
    tile: Color(0xFF38302B),
    tileHi: Color(0xFF2F2823),
    tileEdge: Color(0xFF201B17),
    good: Color(0xFF6FA877),
    goodDeep: Color(0xFF578B60),
    over: Color(0xFFC75F4F),
    line: Color(0xFF453B34),
    shadow: Color(0x66140F0C),
  );

  /// All palettes in shop display order (free → coin ladder → exclusive last).
  static const List<GamePalette> all = [
    clay,
    sage,
    dusk,
    noir,
    tide,
    honey,
    rosewood,
    moss,
    sand,
    plum,
    slate,
    midnight,
    ember,
  ];

  static GamePalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => clay);
}
