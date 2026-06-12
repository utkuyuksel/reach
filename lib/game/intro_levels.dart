import '../engine/difficulty.dart';
import '../engine/models/grid.dart';
import '../engine/models/puzzle.dart';
import '../engine/models/tile.dart';

/// Hand-crafted INTRO LEVELS: when a tile modifier appears for the first
/// time, that Zen level is a small, easy, fixed board featuring it — and the
/// game screen coaches the player through it with the tutorial's gliding
/// finger (industry standard: every new obstacle gets one guided level).
/// The intro IS the level: clearing it advances progression normally, and
/// because Zen levels are deterministic, everyone meets the same intro at
/// the same level.
///
/// All boards are 2×3, target 12, two groups (top row / bottom row), values
/// chosen so the two rows are the ONLY target-summing paths — no accidental
/// clears can skip the lesson. Pure Dart; covered by intro_levels_test.
const Difficulty _introDifficulty = Difficulty(
  id: 'intro',
  rows: 2,
  cols: 3,
  minValue: 1,
  maxValue: 7,
  groupMin: 3,
  groupMax: 3,
);

/// The level at which each modifier debuts (kept in step with the regular
/// modifier schedule in GameController: gold LV 11+, veiled LV 21+,
/// locked LV 31+, wild LV 61+).
const Map<int, TileModifier> kIntroLevels = {
  11: TileModifier.gold,
  21: TileModifier.veiled,
  31: TileModifier.locked,
  61: TileModifier.wild,
};

/// The intro board for [level], or null if it's a regular level.
Puzzle? introPuzzleForLevel(int level) {
  final modifier = kIntroLevels[level];
  if (modifier == null) return null;

  // Base layout: top row 4·5·3 = 12, bottom row 7·2·3 = 12 (the tutorial's
  // proven no-accidental-paths shape).
  Tile t(int id, int value, [TileModifier m = TileModifier.none]) =>
      Tile(id: id, value: value, modifier: m);

  final List<Tile> cells;
  switch (modifier) {
    case TileModifier.gold:
      // One gold tile in the first group: clear it, watch the bonus land.
      cells = [
        t(0, 4), t(1, 5, TileModifier.gold), t(2, 3),
        t(3, 7), t(4, 2), t(5, 3),
      ];
    case TileModifier.veiled:
      // The whole bottom row is fogged; clearing the top row (adjacent)
      // lifts it — the lesson in one move.
      cells = [
        t(0, 4), t(1, 5), t(2, 3),
        t(3, 7, TileModifier.veiled),
        t(4, 2, TileModifier.veiled),
        t(5, 3, TileModifier.veiled),
      ];
    case TileModifier.locked:
      // One locked tile in the bottom row; its key neighbour (cell 1) is in
      // the top row — clear the top, the lock opens.
      cells = [
        t(0, 4), t(1, 5), t(2, 3),
        t(3, 7), t(4, 2, TileModifier.locked), t(5, 3),
      ];
    case TileModifier.wild:
      // The ✦ replaces the 5 (hidden value preserved): tracing the top row
      // shows the wild absorbing whatever is missing.
      cells = [
        t(0, 4), t(1, 5, TileModifier.wild), t(2, 3),
        t(3, 7), t(4, 2), t(5, 3),
      ];
    case TileModifier.none:
      return null;
  }

  return Puzzle(
    initialGrid: Grid(rows: 2, cols: 3, cells: cells),
    target: 12,
    difficulty: _introDifficulty,
    seed: level,
    groups: const [
      [0, 1, 2],
      [3, 4, 5],
    ],
  );
}
