import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';
import 'package:reach/engine/solver.dart';

Grid gridFrom(List<List<int?>> m) {
  final rows = m.length;
  final cols = m[0].length;
  final cells = <Tile?>[];
  var id = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final v = m[r][c];
      cells.add(v == null ? null : Tile(id: id++, value: v));
    }
  }
  return Grid(rows: rows, cols: cols, cells: cells);
}

void main() {
  group('Solver.isCleared', () {
    test('true only when no tiles remain', () {
      expect(Solver.isCleared(gridFrom([[null, null]])), isTrue);
      expect(Solver.isCleared(gridFrom([[1, null]])), isFalse);
    });
  });

  group('Solver.findPartition', () {
    test('finds a full partition into target-sum traceable paths', () {
      final g = gridFrom([
        [2, 3, 2, 3],
      ]);
      final part = Solver.findPartition(g, 5, maxLen: 4);
      expect(part, isNotNull);
      // Covers every cell exactly once.
      final covered = part!.expand((g) => g).toList();
      expect(covered.toSet().length, 4);
      // Each group sums to the target and is a connected path.
      for (final group in part) {
        var sum = 0;
        for (var i = 0; i < group.length; i++) {
          sum += g.at(group[i])!.value;
          if (i > 0) {
            expect(g.areOrthogonalNeighbors(group[i - 1], group[i]), isTrue);
          }
        }
        expect(sum, 5);
      }
    });

    test('returns null when the board cannot be fully cleared', () {
      // No group can even cover cell 0 (no adjacent combo sums to 8).
      final g = gridFrom([
        [4, 1, 4],
      ]);
      expect(Solver.findPartition(g, 8, maxLen: 4), isNull);
      expect(Solver.isSolvable(g, 8, maxLen: 4), isFalse);
    });

    test('isSolvable is true for a partitionable board', () {
      final g = gridFrom([
        [1, 3],
        [3, 1],
      ]);
      expect(Solver.isSolvable(g, 4, maxLen: 4), isTrue);
    });
  });

  group('Solver.countTargetPaths', () {
    test('counts distinct target-sum traceable paths (decoy metric)', () {
      final g = gridFrom([
        [1, 3],
        [3, 1],
      ]);
      // Adjacent pairs summing to 4: {0,1}, {0,2}, {1,3}, {2,3} → 4 paths.
      expect(Solver.countTargetPaths(g, 4, maxLen: 4), 4);
    });

    test('is zero when nothing sums to the target', () {
      final g = gridFrom([
        [1, 1],
        [1, 1],
      ]);
      expect(Solver.countTargetPaths(g, 9, maxLen: 4), 0);
    });
  });

  group('Solver.hint', () {
    test('returns a safe group (part of a real partition)', () {
      final grid = gridFrom([
        [1, 3],
        [3, 1],
      ]);
      final puzzle = Puzzle(
        initialGrid: grid,
        target: 4,
        difficulty: Difficulty.easy,
        seed: 0,
        groups: const [
          [0, 1],
          [2, 3],
        ],
      );
      final hint = Solver.hint(puzzle, grid);
      expect(hint, isNotNull);
      var sum = 0;
      for (final c in hint!) {
        sum += grid.at(c)!.value;
      }
      expect(sum, 4);
    });
  });
}
