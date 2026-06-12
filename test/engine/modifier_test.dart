import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/generator.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';
import 'package:reach/engine/solver.dart';

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

  group('locked tiles', () {
    /// 1×4 [2,2,2,2], target 4, groups [0,1],[2,3]; cell 2 locked. Its
    /// neighbour cell 1 is in the lock-free group [0,1] — clearing it frees
    /// the lock.
    Puzzle lockedLine() {
      final grid = Grid(rows: 1, cols: 4, cells: const [
        Tile(id: 0, value: 2),
        Tile(id: 1, value: 2),
        Tile(id: 2, value: 2, modifier: TileModifier.locked),
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

    test('a locked tile cannot be traced until a neighbouring group clears',
        () {
      var s = GameState.fromPuzzle(lockedLine());
      expect(s.isClearable([2, 3]), isFalse); // gated
      s = s.submitPath([0, 1]); // the key group
      expect(s.grid.at(2)!.modifier, TileModifier.none); // lock opened
      expect(s.isClearable([2, 3]), isTrue);
      s = s.submitPath([2, 3]);
      expect(s.isWon, isTrue);
    });

    test('hasMove ignores locked tiles (a fully gated board is stuck)', () {
      // Only the locked group remains → genuinely no move.
      final grid = Grid(rows: 1, cols: 2, cells: const [
        Tile(id: 0, value: 2, modifier: TileModifier.locked),
        Tile(id: 1, value: 2),
      ]);
      expect(Solver.hasMove(grid, 4), isFalse);
    });

    test('hint never points at a group containing a locked tile', () {
      final s = GameState.fromPuzzle(lockedLine());
      final hint = Solver.hint(s.puzzle, s.grid);
      expect(hint, isNotNull);
      expect(hint!.contains(2), isFalse); // [0,1], not the gated [2,3]
    });

    test('decorate only places locks with a lock-free key group adjacent',
        () {
      for (var seed = 0; seed < 300; seed++) {
        final p = Generator.decorate(
          Generator.generate(difficulty: Difficulty.medium, seed: seed),
          locked: 2,
        );
        final groupOf = <int, int>{};
        for (var g = 0; g < p.groups.length; g++) {
          for (final i in p.groups[g]) {
            groupOf[i] = g;
          }
        }
        final lockedGroups = <int>{};
        final lockedCells = <int>[];
        for (var i = 0; i < p.initialGrid.totalCells; i++) {
          if (p.initialGrid.at(i)?.modifier == TileModifier.locked) {
            lockedCells.add(i);
            lockedGroups.add(groupOf[i]!);
          }
        }
        // Each lock must at least have a key NEIGHBOUR outside its own group.
        // (A later lock may land in an earlier lock's key group — that forms
        // a resolvable CHAIN, not a deadlock; the sweep below is the real
        // resolvability proof.)
        for (final cell in lockedCells) {
          final hasOutsideKey = p.initialGrid.neighborsOf(cell).any((n) {
            final ng = groupOf[n];
            return ng != null && ng != groupOf[cell];
          });
          expect(hasOutsideKey, isTrue,
              reason: 'seed $seed: lock at $cell has no outside neighbour');
        }
        // And a safe order exists: clear lock-free groups first, then keep
        // sweeping the gated ones as their keys open (handles key chains).
        var s = GameState.fromPuzzle(p);
        final free = <List<int>>[];
        var gated = <List<int>>[];
        for (var g = 0; g < p.groups.length; g++) {
          (lockedGroups.contains(g) ? gated : free).add(p.groups[g]);
        }
        for (final g in free) {
          s = s.submitPath(g);
        }
        var progress = true;
        while (gated.isNotEmpty && progress) {
          progress = false;
          final remaining = <List<int>>[];
          for (final g in gated) {
            final next = s.submitPath(g);
            if (identical(next, s)) {
              remaining.add(g); // still locked — retry after others clear
            } else {
              s = next;
              progress = true;
            }
          }
          gated = remaining;
        }
        expect(s.isWon, isTrue, reason: 'seed $seed not winnable with locks');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('wildcard tiles', () {
    /// 1×4 [4,5,3,2], target 12, groups [0,1,2],[3...]? — keep simple:
    /// 2×2 grid, target 12: [4,5] + wild(3-hidden),2? Use a focused board:
    /// row [4, ✦(5 hidden), 3, 2] target 12; groups [0,1,2] (4+5+3) + [3]?
    /// Groups must each sum to target, so craft: [4,5,3] and a 1-cell group
    /// is invalid — use 2×3: groups [0,1,2]=12 and [3,4,5]=12.
    Puzzle wildBoard() {
      final grid = Grid(rows: 2, cols: 3, cells: const [
        Tile(id: 0, value: 4),
        Tile(id: 1, value: 5, modifier: TileModifier.wild), // hidden 5
        Tile(id: 2, value: 3),
        Tile(id: 3, value: 7),
        Tile(id: 4, value: 2),
        Tile(id: 5, value: 3),
      ]);
      return Puzzle(
        initialGrid: grid,
        target: 12,
        difficulty: Difficulty.easy,
        seed: 0,
        groups: const [
          [0, 1, 2],
          [3, 4, 5],
        ],
      );
    }

    test('a wild absorbs whatever the trace is missing', () {
      final s = GameState.fromPuzzle(wildBoard());
      // 4 + ✦ alone: 4 ≤ 12-1 → the wild covers 8.
      expect(s.isClearable([0, 1]), isTrue);
      // 4 + ✦ + 3 = construction group, also fine.
      expect(s.isClearable([0, 1, 2]), isTrue);
      // Non-wild overshoot still rejected: 7+2+3=12 exact fine...
      expect(s.isClearable([3, 4, 5]), isTrue);
      // ...but 4+3 (no wild, sum 7 ≠ 12) is not clearable.
      expect(s.isClearable([0, 2]), isFalse);
    });

    test('a wild trace must leave the wild at least 1 to absorb', () {
      // Row [9, ✦, 9], target 12: 9+✦ ok (✦=3); 9+✦+9=18 non-wild sum
      // exceeds target-1 → rejected.
      final grid = Grid(rows: 1, cols: 3, cells: const [
        Tile(id: 0, value: 9),
        Tile(id: 1, value: 3, modifier: TileModifier.wild),
        Tile(id: 2, value: 9),
      ]);
      final p = Puzzle(
        initialGrid: grid,
        target: 12,
        difficulty: Difficulty.easy,
        seed: 0,
        groups: const [
          [0, 1],
          [2],
        ], // groups unused by isClearable
      );
      final s = GameState.fromPuzzle(p);
      expect(s.isClearable([0, 1]), isTrue); // 9 ≤ 11
      expect(s.isClearable([0, 1, 2]), isFalse); // 18 > 11
    });

    test('hasMove sees wild moves (and true isolation is still stuck)', () {
      // Wild with one unlocked neighbour → always a move.
      final lively = Grid(rows: 1, cols: 2, cells: const [
        Tile(id: 0, value: 9, modifier: TileModifier.wild),
        Tile(id: 1, value: 9),
      ]);
      expect(Solver.hasMove(lively, 12), isTrue);
      // Wild whose only neighbour is locked → genuinely stuck.
      final gated = Grid(rows: 1, cols: 2, cells: const [
        Tile(id: 0, value: 9, modifier: TileModifier.wild),
        Tile(id: 1, value: 9, modifier: TileModifier.locked),
      ]);
      expect(Solver.hasMove(gated, 12), isFalse);
    });

    test('the construction solution still wins (hidden value keeps solver exact)',
        () {
      var s = GameState.fromPuzzle(wildBoard());
      for (final g in s.puzzle.groups) {
        s = s.submitPath(g);
      }
      expect(s.isWon, isTrue);
      // And the hint/partition machinery still works on a wild board.
      final fresh = GameState.fromPuzzle(wildBoard());
      expect(Solver.hint(fresh.puzzle, fresh.grid), isNotNull);
    });

    test('decorate places at most one wild, disjoint from other modifiers',
        () {
      for (var seed = 0; seed < 200; seed++) {
        final p = Generator.decorate(
          Generator.generate(difficulty: Difficulty.medium, seed: seed),
          veiled: 3,
          gold: 1,
          locked: 1,
          wild: 1,
        );
        var wilds = 0;
        for (var i = 0; i < p.initialGrid.totalCells; i++) {
          final t = p.initialGrid.at(i)!;
          if (t.modifier == TileModifier.wild) wilds++;
        }
        expect(wilds, 1, reason: 'seed $seed');
        // Replay the construction groups (locked groups last, swept).
        var s = GameState.fromPuzzle(p);
        var pending = List<List<int>>.from(p.groups);
        var progress = true;
        while (pending.isNotEmpty && progress) {
          progress = false;
          final rest = <List<int>>[];
          for (final g in pending) {
            final next = s.submitPath(g);
            if (identical(next, s)) {
              rest.add(g);
            } else {
              s = next;
              progress = true;
            }
          }
          pending = rest;
        }
        expect(s.isWon, isTrue, reason: 'seed $seed not winnable with wild');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
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
