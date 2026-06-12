import 'models/grid.dart';
import 'models/tile.dart';
import 'models/puzzle.dart';

/// Solvability + safe hints for the find-and-clear mechanic.
///
/// The central operation is [findPartition]: can the occupied cells be split
/// into connected, *traceable* paths that each sum to the target? This drives
/// two guarantees:
///   * **safe hints** — a hint is always the first group of a real partition of
///     the *current* board, so following it can never strand the board;
///   * **no dead-ends** — [GameState] only applies a clear if the remaining
///     board is still partitionable (otherwise the move is gently rejected).
///
/// Pure Dart — no Flutter imports.
class Solver {
  static bool isCleared(Grid grid) => grid.occupiedIndices().isEmpty;

  /// Partition the occupied cells into connected, traceable paths each summing
  /// to [target], or null if impossible. [maxLen] caps group size (pass the
  /// difficulty's groupMax). [budget] bounds the backtracking search; if it is
  /// exhausted the method returns null (callers treat that conservatively).
  static List<List<int>>? findPartition(
    Grid grid,
    int target, {
    required int maxLen,
    int budget = 200000,
  }) {
    final remaining = <int>{...grid.occupiedIndices()};
    final result = <List<int>>[];
    if (_solve(grid, target, maxLen, remaining, result, _Budget(budget))) {
      return result.map((g) => List<int>.unmodifiable(g)).toList();
    }
    return null;
  }

  /// Whether the current board can still be fully cleared.
  static bool isSolvable(Grid grid, int target, {required int maxLen}) =>
      grid.occupiedIndices().isEmpty ||
      findPartition(grid, target, maxLen: maxLen) != null;

  /// Whether ANY clearable group exists right now (a connected path of ≥2
  /// occupied cells summing to [target]). The cheap "can the player do
  /// anything?" check — when false and the board isn't empty, the player has
  /// played into a stuck position (like leftover pegs in peg solitaire).
  /// Early-exits on the first move found.
  static bool hasMove(Grid grid, int target, {int maxLen = 64}) {
    for (final start in grid.occupiedIndices()) {
      final t = grid.at(start)!;
      if (t.modifier == TileModifier.locked) continue;
      if (t.modifier == TileModifier.wild) {
        // A wild + any unlocked neighbour always clears: the neighbour's
        // value ≤ maxValue < target, so the wild can absorb the rest.
        for (final n in grid.neighborsOf(start)) {
          final nt = grid.at(n);
          if (nt != null && nt.modifier != TileModifier.locked) return true;
        }
        continue; // isolated wild — fall through to normal search
      }
      if (_hasPath(grid, target, start, 1 << start, t.value, maxLen)) {
        return true;
      }
    }
    return false;
  }

  static bool _hasPath(
    Grid grid,
    int target,
    int last,
    int mask,
    int sum,
    int maxLen,
  ) {
    if (sum == target && _popcount(mask) >= 2) return true;
    if (sum >= target || _popcount(mask) >= maxLen) return false;
    for (final nb in grid.neighborsOf(last)) {
      final t = grid.at(nb);
      if (t == null ||
          t.modifier == TileModifier.locked ||
          t.modifier == TileModifier.wild || // wild moves found via shortcut
          (mask & (1 << nb)) != 0) {
        continue;
      }
      if (_hasPath(grid, target, nb, mask | (1 << nb),
          sum + t.value, maxLen)) {
        return true;
      }
    }
    return false;
  }

  /// A safe hint: the first group of a valid partition of the current board.
  /// Null only if the board is unsolvable (which the game prevents).
  static List<int>? hint(Puzzle puzzle, Grid grid) {
    final partition =
        findPartition(grid, puzzle.target, maxLen: puzzle.difficulty.groupMax);
    if (partition == null || partition.isEmpty) return null;
    // Never hint a group the player can't trace yet (contains a locked tile).
    for (final group in partition) {
      final traceable = group.every(
          (i) => grid.at(i)!.modifier != TileModifier.locked);
      if (traceable) return group;
    }
    return partition.first; // all gated (transient) — show the first anyway
  }

  /// Count the distinct connected, *traceable* paths that sum to [target] on
  /// the board (capped at [cap]). Subtracting the number of solution groups
  /// gives the "decoy" count — the false-lead density that makes a board hard
  /// and drives hint demand. [maxLen] caps path length. Each path is counted
  /// once, via its minimum-index cell.
  static int countTargetPaths(
    Grid grid,
    int target, {
    required int maxLen,
    int cap = 80,
  }) {
    final n = grid.totalCells;
    var count = 0;
    for (final pivot in grid.occupiedIndices()) {
      final seen = <int>{1 << pivot};
      var frontier = <List<int>>[
        [1 << pivot, grid.at(pivot)!.value],
      ];
      while (frontier.isNotEmpty) {
        final next = <List<int>>[];
        for (final entry in frontier) {
          final mask = entry[0];
          final sum = entry[1];
          if (sum == target) {
            if (_hamPath(grid, mask) != null) {
              count++;
              if (count >= cap) return cap;
            }
            continue;
          }
          if (_popcount(mask) >= maxLen) continue;
          for (var i = 0; i < n; i++) {
            if ((mask & (1 << i)) == 0) continue;
            for (final nb in grid.neighborsOf(i)) {
              // Keep `pivot` the minimum member so each subset is counted once.
              if (nb <= pivot) continue;
              if (grid.at(nb) == null || (mask & (1 << nb)) != 0) continue;
              final ns = sum + grid.at(nb)!.value;
              if (ns > target) continue;
              final nm = mask | (1 << nb);
              if (!seen.add(nm)) continue;
              next.add([nm, ns]);
            }
          }
        }
        frontier = next;
      }
    }
    return count;
  }

  static bool _solve(
    Grid grid,
    int target,
    int maxLen,
    Set<int> remaining,
    List<List<int>> result,
    _Budget budget,
  ) {
    if (remaining.isEmpty) return true;
    if (budget.exhausted) return false;

    // Cover the lowest-index remaining cell first — it must belong to some
    // group, which keeps branching low.
    var pivot = -1;
    for (final i in remaining) {
      if (pivot < 0 || i < pivot) pivot = i;
    }

    for (final group in _groupsContaining(grid, target, maxLen, remaining, pivot)) {
      remaining.removeAll(group);
      result.add(group);
      if (_solve(grid, target, maxLen, remaining, result, budget)) return true;
      result.removeLast();
      remaining.addAll(group);
    }
    return false;
  }

  /// Traceable paths within [remaining] that contain [pivot] and sum to target.
  static List<List<int>> _groupsContaining(
    Grid grid,
    int target,
    int maxLen,
    Set<int> remaining,
    int pivot,
  ) {
    final out = <List<int>>[];
    final startMask = 1 << pivot;
    final seen = <int>{startMask};
    var frontier = <List<int>>[
      [startMask, grid.at(pivot)!.value],
    ];

    while (frontier.isNotEmpty) {
      final next = <List<int>>[];
      for (final entry in frontier) {
        final mask = entry[0];
        final sum = entry[1];
        if (sum == target) {
          final path = _hamPath(grid, mask);
          if (path != null) out.add(path);
          continue; // growing further only overshoots (positive values)
        }
        if (_popcount(mask) >= maxLen) continue;
        for (var i = 0; i < grid.totalCells; i++) {
          if ((mask & (1 << i)) == 0) continue;
          for (final nb in grid.neighborsOf(i)) {
            if (!remaining.contains(nb) || (mask & (1 << nb)) != 0) continue;
            final nsum = sum + grid.at(nb)!.value;
            if (nsum > target) continue;
            final nmask = mask | (1 << nb);
            if (!seen.add(nmask)) continue;
            next.add([nmask, nsum]);
          }
        }
      }
      frontier = next;
    }
    return out;
  }

  /// A Hamiltonian path ordering of the cells in [mask] (so the group is
  /// traceable by a single drag), or null if the shape isn't traceable.
  static List<int>? _hamPath(Grid grid, int mask) {
    final cells = <int>[];
    for (var i = 0; i < grid.totalCells; i++) {
      if ((mask & (1 << i)) != 0) cells.add(i);
    }
    if (cells.length < 2) return cells;

    final n = cells.length;
    final path = <int>[];
    final used = <int>{};

    bool dfs(int cur) {
      path.add(cur);
      used.add(cur);
      if (path.length == n) return true;
      for (final nb in grid.neighborsOf(cur)) {
        if ((mask & (1 << nb)) == 0 || used.contains(nb)) continue;
        if (dfs(nb)) return true;
      }
      path.removeLast();
      used.remove(cur);
      return false;
    }

    for (final start in cells) {
      path.clear();
      used.clear();
      if (dfs(start)) return List<int>.from(path);
    }
    return null;
  }

  static int _popcount(int x) {
    var c = 0;
    var v = x;
    while (v != 0) {
      c += v & 1;
      v >>= 1;
    }
    return c;
  }
}

class _Budget {
  int _left;
  _Budget(this._left);
  bool get exhausted => --_left < 0;
}
