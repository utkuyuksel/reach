import '../solver.dart';
import 'grid.dart';
import 'puzzle.dart';
import 'tile.dart';

enum GameStatus { playing, won }

/// An immutable snapshot of an in-progress game. The player traces a path of
/// orthogonally-adjacent tiles; if it sums exactly to the target, that group
/// clears. The board is won when every tile is cleared.
///
/// All interactions return a new [GameState]; nothing mutates in place, so undo
/// is trivial and the logic is fully unit-testable. The in-progress drag path
/// is UI-transient and lives in the widget — this model only commits whole
/// groups via [submitPath].
///
/// Pure Dart — no Flutter imports.
class GameState {
  final Puzzle puzzle;
  final Grid grid;

  /// Cleared groups, oldest first (each an ordered path of cell indices). One
  /// entry per clear, so `found == clearedGroups.length` and undo pops the last.
  final List<List<int>> clearedGroups;

  final GameStatus status;

  const GameState({
    required this.puzzle,
    required this.grid,
    required this.clearedGroups,
    required this.status,
  });

  factory GameState.fromPuzzle(Puzzle puzzle) => GameState(
        puzzle: puzzle,
        grid: puzzle.initialGrid,
        clearedGroups: const [],
        status: GameStatus.playing,
      );

  int get target => puzzle.target;
  int get found => clearedGroups.length;
  int get totalGroups => puzzle.groupCount;
  bool get isWon => status == GameStatus.won;
  bool get canUndo => clearedGroups.isNotEmpty;

  /// Whether [path] is a clearable group on the current board: at least two
  /// distinct, currently-occupied cells, each consecutive pair orthogonally
  /// adjacent (a real traceable path), summing exactly to the target.
  bool isClearable(List<int> path) {
    if (status == GameStatus.won) return false;
    if (path.length < 2) return false;
    final seen = <int>{};
    var sum = 0;
    for (var i = 0; i < path.length; i++) {
      final cell = path[i];
      if (!seen.add(cell)) return false; // repeated cell
      final tile = grid.at(cell);
      if (tile == null) return false; // already cleared / empty
      if (i > 0 && !grid.areOrthogonalNeighbors(path[i - 1], cell)) {
        return false; // not a connected trace
      }
      sum += tile.value;
      if (sum > target) return false; // positive values — can't recover
    }
    return sum == target;
  }

  /// Clear [path] if it is a valid group; otherwise return this unchanged
  /// (no penalty for a wrong trace). A valid trace ALWAYS clears, even if it
  /// strands the board — the controller detects a stranded board and surfaces
  /// a gentle "undo / hint" prompt rather than silently rejecting the move.
  GameState submitPath(List<int> path) {
    if (!isClearable(path)) return this;
    final next = _unveilAround(grid.cleared(path), path);
    final won = next.occupiedIndices().isEmpty;
    return GameState(
      puzzle: puzzle,
      grid: next,
      clearedGroups: [...clearedGroups, List<int>.unmodifiable(path)],
      status: won ? GameStatus.won : GameStatus.playing,
    );
  }

  /// Lift the veil from tiles orthogonally adjacent to the just-cleared
  /// [path] — clearing the edges of the fog is how veiled boards open up.
  static Grid _unveilAround(Grid grid, List<int> path) {
    final toReveal = <int>{};
    for (final cleared in path) {
      for (final n in grid.neighborsOf(cleared)) {
        final t = grid.at(n);
        if (t != null && t.modifier == TileModifier.veiled) toReveal.add(n);
      }
    }
    if (toReveal.isEmpty) return grid;
    final cells = List<Tile?>.from(grid.cells);
    for (final i in toReveal) {
      cells[i] = cells[i]!.unveiled();
    }
    return Grid(rows: grid.rows, cols: grid.cols, cells: cells);
  }

  /// Whether the player can still make ANY move (some connected path sums to
  /// the target). When false and the board isn't empty, the player has played
  /// into a stuck position — the UI then offers undo/restart. We do NOT warn
  /// the moment the board becomes *unwinnable*; like peg solitaire, the player
  /// keeps going and discovers the dead end only when no move remains.
  bool get hasMove =>
      isWon ||
      grid.occupiedIndices().isEmpty ||
      Solver.hasMove(grid, target);

  /// Undo the last cleared group, restoring its original tiles. No-op if there
  /// is nothing to undo. Returns to the playing state.
  GameState undo() {
    if (clearedGroups.isEmpty) return this;
    final last = clearedGroups.last;
    final restored = grid.restoredFrom(puzzle.initialGrid, last);
    return GameState(
      puzzle: puzzle,
      grid: restored,
      clearedGroups: clearedGroups.sublist(0, clearedGroups.length - 1),
      status: GameStatus.playing,
    );
  }

  /// Reset to the starting board.
  GameState restart() => GameState.fromPuzzle(puzzle);
}
