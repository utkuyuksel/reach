import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';

/// 2×2 board, target 4. Partition: [0,1] = 1+3, [2,3] = 3+1.
///   1 3
///   3 1
Puzzle _puzzle() {
  final grid = Grid(rows: 2, cols: 2, cells: [
    Tile(id: 0, value: 1),
    Tile(id: 1, value: 3),
    Tile(id: 2, value: 3),
    Tile(id: 3, value: 1),
  ]);
  return Puzzle(
    initialGrid: grid,
    target: 4,
    difficulty: Difficulty.easy,
    seed: 0,
    groups: const [
      [0, 1],
      [2, 3],
    ],
  );
}

void main() {
  group('GameState.submitPath', () {
    test('clears a valid group and counts it', () {
      var s = GameState.fromPuzzle(_puzzle());
      s = s.submitPath([0, 1]); // 1 + 3 = 4
      expect(s.found, 1);
      expect(s.grid.at(0), isNull);
      expect(s.grid.at(1), isNull);
      expect(s.isWon, isFalse);
    });

    test('clearing all groups wins (board empty)', () {
      var s = GameState.fromPuzzle(_puzzle());
      s = s.submitPath([0, 1]);
      s = s.submitPath([2, 3]);
      expect(s.isWon, isTrue);
      expect(s.found, 2);
    });

    test('wrong sum is rejected with no penalty', () {
      var s = GameState.fromPuzzle(_puzzle());
      final before = s;
      s = s.submitPath([0, 2]); // 1 + 3 = 4 — actually valid (vertical)
      expect(s.found, 1);
      // A genuinely wrong sum:
      var t = before;
      t = t.submitPath([0, 1, 2]); // 1+3+3 = 7 ≠ 4
      expect(t.found, 0);
      expect(identical(t, before), isTrue);
    });

    test('non-adjacent (diagonal) trace is rejected', () {
      var s = GameState.fromPuzzle(_puzzle());
      final r = s.submitPath([0, 3]); // diagonal, not a path
      expect(r.found, 0);
      expect(identical(r, s), isTrue);
    });

    test('single cell and repeated cell are rejected', () {
      final s = GameState.fromPuzzle(_puzzle());
      expect(s.submitPath([0]).found, 0); // too short
      expect(s.submitPath([0, 0]).found, 0); // repeat
    });

    test('cannot trace an already-cleared cell', () {
      var s = GameState.fromPuzzle(_puzzle());
      s = s.submitPath([0, 1]); // clears 0,1
      final r = s.submitPath([0, 1]); // empty now
      expect(r.found, 1);
      expect(identical(r, s), isTrue);
    });
  });

  group('GameState no-dead-ends', () {
    // 1×4 of 2s, target 4. Partition: [0,1] and [2,3].
    Puzzle line() {
      final grid = Grid(rows: 1, cols: 4, cells: [
        Tile(id: 0, value: 2),
        Tile(id: 1, value: 2),
        Tile(id: 2, value: 2),
        Tile(id: 3, value: 2),
      ]);
      return Puzzle(
        initialGrid: grid,
        target: 4,
        difficulty: Difficulty.easy,
        seed: 0,
        groups: const [
          [0, 1],
          [2, 3],
        ],
      );
    }

    test('clearing into a dead end leaves no moves (peg-solitaire style)', () {
      final s = GameState.fromPuzzle(line());
      // [1,2] clears but isolates cells 0 and 3 — nothing sums to 4 anymore.
      final after = s.submitPath([1, 2]);
      expect(after.found, 1);
      expect(after.hasMove, isFalse); // stuck — UI prompts undo/restart

      // Undo recovers a playable board.
      final back = after.undo();
      expect(back.found, 0);
      expect(back.hasMove, isTrue);

      // A safe move keeps moves available.
      expect(s.submitPath([0, 1]).hasMove, isTrue);
    });
  });

  group('GameState undo & restart', () {
    test('undo restores the last cleared group', () {
      var s = GameState.fromPuzzle(_puzzle());
      final initial = s.grid;
      s = s.submitPath([0, 1]);
      expect(s.found, 1);
      s = s.undo();
      expect(s.found, 0);
      expect(s.grid, initial);
      expect(s.canUndo, isFalse);
    });

    test('undo clears the win', () {
      var s = GameState.fromPuzzle(_puzzle());
      s = s.submitPath([0, 1]);
      s = s.submitPath([2, 3]);
      expect(s.isWon, isTrue);
      s = s.undo();
      expect(s.isWon, isFalse);
      expect(s.found, 1);
    });

    test('restart returns to the full board', () {
      var s = GameState.fromPuzzle(_puzzle());
      final initial = s.grid;
      s = s.submitPath([0, 1]);
      s = s.restart();
      expect(s.found, 0);
      expect(s.grid, initial);
    });
  });
}
