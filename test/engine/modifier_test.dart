import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/generator.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';

/// Modifier tiles decorate an already-solvable board — these guard the two
/// invariants that make that safe: values/groups are NEVER altered, and the
/// veil lifts exactly when a neighbouring group clears.
void main() {
  group('Generator.decorate', () {
    test('honours counts, keeps cells disjoint, never alters values', () {
      final plain =
          Generator.generateTuned(difficulty: Difficulty.medium, seed: 42);
      final deco = Generator.decorate(plain, veiled: 3, gold: 2);

      var veiled = 0, gold = 0;
      for (var i = 0; i < plain.initialGrid.totalCells; i++) {
        final a = plain.initialGrid.at(i);
        final b = deco.initialGrid.at(i);
        expect(b!.value, a!.value); // values untouched
        expect(b.id, a.id);
        if (b.modifier == TileModifier.veiled) veiled++;
        if (b.modifier == TileModifier.gold) gold++;
      }
      expect(veiled, 3);
      expect(gold, 2);
      expect(deco.groups, plain.groups); // partition untouched
      expect(deco.target, plain.target);
    });

    test('is deterministic per seed', () {
      final p =
          Generator.generateTuned(difficulty: Difficulty.medium, seed: 7);
      final a = Generator.decorate(p, veiled: 4, gold: 1);
      final b = Generator.decorate(p, veiled: 4, gold: 1);
      expect(a.initialGrid, b.initialGrid);
    });

    test('zero counts are a no-op', () {
      final p =
          Generator.generateTuned(difficulty: Difficulty.easy, seed: 3);
      expect(identical(Generator.decorate(p), p), isTrue);
    });
  });

  group('veil lifting', () {
    /// 1×4 row [2,2,2,2], target 4, groups [0,1],[2,3]; cell 2 veiled,
    /// cell 3 veiled. Clearing [0,1] unveils its neighbour 2, not 3.
    Puzzle veiledLine() {
      final grid = Grid(rows: 1, cols: 4, cells: const [
        Tile(id: 0, value: 2),
        Tile(id: 1, value: 2),
        Tile(id: 2, value: 2, modifier: TileModifier.veiled),
        Tile(id: 3, value: 2, modifier: TileModifier.veiled),
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

    test('clearing a group unveils orthogonal neighbours only', () {
      var s = GameState.fromPuzzle(veiledLine());
      s = s.submitPath([0, 1]);
      expect(s.grid.at(2)!.modifier, TileModifier.none); // adjacent: lifted
      expect(s.grid.at(3)!.modifier, TileModifier.veiled); // far: still foggy
    });

    test('veiled tiles are fully traceable (values are real)', () {
      var s = GameState.fromPuzzle(veiledLine());
      expect(s.isClearable([2, 3]), isTrue); // trace straight into the fog
      s = s.submitPath([2, 3]);
      s = s.submitPath([0, 1]);
      expect(s.isWon, isTrue);
    });
  });

  group('decorated stress (values & winnability survive decoration)', () {
    test('2k medium boards with veil+gold replay to a win', () {
      for (var seed = 0; seed < 2000; seed++) {
        final p = Generator.decorate(
          Generator.generate(difficulty: Difficulty.medium, seed: seed),
          veiled: 4,
          gold: 2,
        );
        var s = GameState.fromPuzzle(p);
        for (final g in p.groups) {
          s = s.submitPath(g);
        }
        expect(s.isWon, isTrue, reason: 'seed $seed failed after decoration');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
