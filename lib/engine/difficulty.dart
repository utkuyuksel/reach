import 'dart:math' as math;

/// A difficulty configuration for the "find groups summing to the target,
/// clear the board" mechanic.
///
/// The board is partitioned into connected groups (paths) whose tile values
/// each sum to a per-board target. Difficulty scales the way word-search does:
/// bigger boards with more groups, wider value ranges — not by punishing the
/// player. The target is always chosen above [maxValue], so a single tile can
/// never equal it (no trivial one-tap clears).
///
/// Pure Dart — no Flutter imports.
class Difficulty {
  /// Stable identifier (persistence keys, personal bests).
  final String id;
  final int rows;
  final int cols;

  /// Inclusive tile-value range.
  final int minValue;
  final int maxValue;

  /// Inclusive group (path) size range. Must span at least two consecutive
  /// sizes so any cell count can be partitioned, and satisfy
  /// `2 <= groupMin <= groupMax`.
  final int groupMin;
  final int groupMax;

  /// Desired "decoy" band: how many target-summing paths exist BEYOND the
  /// solution groups (false leads). The generator biases toward this band, so
  /// difficulty/hint-demand scales without ever risking solvability.
  final int decoyMin;
  final int decoyMax;

  const Difficulty({
    required this.id,
    required this.rows,
    required this.cols,
    required this.minValue,
    required this.maxValue,
    required this.groupMin,
    required this.groupMax,
    this.decoyMin = 0,
    this.decoyMax = 64,
  });

  int get totalCells => rows * cols;

  /// Smallest valid per-board target: strictly above [maxValue] (so no single
  /// tile equals the target) and reachable by the largest group.
  int get targetMin => math.max(maxValue + 1, groupMax * minValue);

  /// Largest valid per-board target: reachable by the smallest group.
  int get targetMax => groupMin * maxValue;

  /// Whether a usable target range exists (a config invariant).
  bool get hasValidTargetRange => targetMin <= targetMax;

  // --- Named tiers for the difficulty selector. ---
  static const Difficulty easy = Difficulty(
    id: 'easy',
    rows: 4,
    cols: 4,
    minValue: 1,
    maxValue: 5,
    groupMin: 2,
    groupMax: 4,
    decoyMin: 0,
    decoyMax: 4,
  );

  static const Difficulty medium = Difficulty(
    id: 'medium',
    rows: 5,
    cols: 5,
    minValue: 1,
    maxValue: 7,
    groupMin: 2,
    groupMax: 4,
    decoyMin: 1,
    decoyMax: 8,
  );

  static const Difficulty hard = Difficulty(
    id: 'hard',
    rows: 6,
    cols: 6,
    minValue: 1,
    maxValue: 9,
    groupMin: 2,
    groupMax: 4,
    decoyMin: 3,
    decoyMax: 14,
  );

  static const List<Difficulty> tiers = [easy, medium, hard];

  static Difficulty byId(String id) =>
      tiers.firstWhere((d) => d.id == id, orElse: () => easy);

  /// Fixed difficulty for the Daily Challenge (same for everyone).
  static const Difficulty daily = medium;

  /// Endless ramp for Zen mode — gentle, and *infinite* (never plateaus).
  /// Difficulty scales like a word search: a bigger grid with more (and
  /// gradually longer) groups, and a larger target — never via multi-digit
  /// numbers. A gentle small-board intro eases newcomers in.
  static Difficulty endlessForLevel(int level) {
    final l = level < 0 ? 0 : level;

    final int rows;
    final int cols;
    if (l < 2) {
      rows = 3;
      cols = 4; // 12 — gentle intro
    } else if (l < 5) {
      rows = 4;
      cols = 4; // 16
    } else if (l < 9) {
      rows = 4;
      cols = 5; // 20
    } else if (l < 14) {
      rows = 5;
      cols = 5; // 25
    } else if (l < 20) {
      rows = 5;
      cols = 6; // 30
    } else {
      rows = 6;
      cols = 6; // 36 — cap board area for snappy hint/solve
    }

    final maxValue = 5 + l ~/ 3 > 9 ? 9 : 5 + l ~/ 3;
    // Groups (and thus the target) grow with the level.
    final step = l ~/ 8 > 2 ? 2 : l ~/ 8;
    final groupMin = 2 + step; // 2 → 4
    final groupMax = groupMin + 2; // spans 3 sizes (any cell count composes)

    // Decoy density (false leads) rises with the level — the difficulty and
    // hint-demand curve. Early boards are gentle (few decoys); later boards are
    // dense with near-misses.
    final decoyMin = l ~/ 4 > 8 ? 8 : l ~/ 4;
    final decoyGrow = l ~/ 2 > 16 ? 16 : l ~/ 2;
    final decoyMax = decoyMin + 4 + decoyGrow;

    return Difficulty(
      id: 'lvl-$l',
      rows: rows,
      cols: cols,
      minValue: 1,
      maxValue: maxValue,
      groupMin: groupMin,
      groupMax: groupMax,
      decoyMin: decoyMin,
      decoyMax: decoyMax,
    );
  }

  /// Number of board clears per displayed "level" in Zen.
  static const int clearsPerLevel = 1;

  @override
  String toString() =>
      'Difficulty($id ${rows}x$cols v$minValue-$maxValue g$groupMin-$groupMax '
      'target $targetMin-$targetMax)';
}
