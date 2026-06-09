import '../engine/difficulty.dart';
import '../engine/models/grid.dart';
import '../engine/models/puzzle.dart';
import '../engine/models/tile.dart';

/// Difficulty metadata for the hand-crafted onboarding board. It is NOT part of
/// [Difficulty.tiers] or the Zen ladder, so the generator stress test never
/// sees it — it exists only to satisfy [Puzzle.difficulty].
const Difficulty _tutorialDifficulty = Difficulty(
  id: 'tutorial',
  rows: 2,
  cols: 3,
  minValue: 2,
  maxValue: 7,
  groupMin: 2,
  groupMax: 3,
);

/// A fixed, bulletproof first-run board used by the interactive tutorial:
///
/// ```
///   4 5 3
///   7 2 3      target 12
/// ```
///
/// The ONLY two connected, traceable paths that sum to 12 are the two rows
/// (`[0,1,2]` and `[3,4,5]`). That means: no accidental clears, the board wins
/// in either clear order, and the player can never strand themselves — a
/// frustration-free first success. All of this is asserted in
/// `test/engine/tutorial_puzzle_test.dart`.
///
/// Pure Dart (engine only, no Flutter) so it is unit-testable.
Puzzle tutorialPuzzle() {
  const values = [4, 5, 3, 7, 2, 3];
  final cells = <Tile?>[
    for (var i = 0; i < values.length; i++) Tile(id: i, value: values[i]),
  ];
  return Puzzle(
    initialGrid: Grid(rows: 2, cols: 3, cells: cells),
    target: 12,
    difficulty: _tutorialDifficulty,
    seed: 0,
    groups: const [
      [0, 1, 2],
      [3, 4, 5],
    ],
  );
}
