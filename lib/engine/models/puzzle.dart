import '../difficulty.dart';
import 'grid.dart';

/// An immutable, fully-specified puzzle: the starting board, the target every
/// group must sum to, and the partition that proves the board is fully
/// clearable.
///
/// Pure Dart — no Flutter imports.
class Puzzle {
  /// The starting board (a full grid of tiles).
  final Grid initialGrid;

  /// The number every cleared group's tiles must sum to.
  final int target;

  /// The difficulty configuration this puzzle was generated from.
  final Difficulty difficulty;

  /// The seed used to generate this puzzle (date-derived for Daily).
  final int seed;

  /// The construction partition: a list of groups, each an *ordered path* of
  /// cell indices whose tiles sum to [target]. Together they cover every cell
  /// exactly once. This is the solvability witness (the board can always be
  /// fully cleared) and the basis for hints.
  final List<List<int>> groups;

  const Puzzle({
    required this.initialGrid,
    required this.target,
    required this.difficulty,
    required this.seed,
    required this.groups,
  });

  /// Number of groups to find to clear the board.
  int get groupCount => groups.length;
}
