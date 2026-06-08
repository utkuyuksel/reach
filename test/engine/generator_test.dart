import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/generator.dart';
import 'package:reach/engine/models/game_state.dart';

void main() {
  group('Generator determinism', () {
    test('same seed + difficulty produces an identical board', () {
      final a = Generator.generate(difficulty: Difficulty.medium, seed: 42);
      final b = Generator.generate(difficulty: Difficulty.medium, seed: 42);
      expect(a.target, b.target);
      expect(a.groups, b.groups);
      expect(a.initialGrid, b.initialGrid);
    });

    test('different seeds usually differ', () {
      final targets = <String>{};
      for (var seed = 0; seed < 50; seed++) {
        final p = Generator.generate(difficulty: Difficulty.medium, seed: seed);
        targets.add('${p.target}|${p.groups.length}|${p.initialGrid.hashCode}');
      }
      expect(targets.length, greaterThan(10));
    });
  });

  group('dailySeed', () {
    test('encodes the date as YYYYMMDD', () {
      expect(Generator.dailySeed(DateTime(2026, 6, 8)), 20260608);
      expect(Generator.dailySeed(DateTime(2026, 12, 31)), 20261231);
    });

    test('same date yields the same daily board', () {
      final seed = Generator.dailySeed(DateTime(2026, 6, 8));
      final a = Generator.generate(difficulty: Difficulty.daily, seed: seed);
      final b = Generator.generate(difficulty: Difficulty.daily, seed: seed);
      expect(a.initialGrid, b.initialGrid);
      expect(a.target, b.target);
    });
  });

  group('Difficulty configs', () {
    test('every tier has a valid target range above maxValue', () {
      for (final d in Difficulty.tiers) {
        expect(d.hasValidTargetRange, isTrue, reason: d.id);
        expect(d.targetMin, greaterThan(d.maxValue), reason: d.id);
      }
    });

    test('endless levels are valid and never throw across a wide range', () {
      for (var level = 0; level < 60; level++) {
        final d = Difficulty.endlessForLevel(level);
        expect(d.hasValidTargetRange, isTrue, reason: 'level $level');
        expect(d.targetMin, greaterThan(d.maxValue), reason: 'level $level');
        expect(d.groupMax, greaterThanOrEqualTo(d.groupMin));
        // Board grows but stays bounded.
        expect(d.totalCells, inInclusiveRange(8, 42));
      }
    });

    test('endless board size is non-decreasing', () {
      var lastCells = 0;
      for (var level = 0; level < 40; level++) {
        final cells = Difficulty.endlessForLevel(level).totalCells;
        expect(cells, greaterThanOrEqualTo(lastCells));
        lastCells = cells;
      }
    });

    test('decoy band is valid and rises with level', () {
      for (final d in Difficulty.tiers) {
        expect(d.decoyMax, greaterThanOrEqualTo(d.decoyMin));
      }
      var lastMax = 0;
      for (var level = 0; level < 40; level += 4) {
        final d = Difficulty.endlessForLevel(level);
        expect(d.decoyMax, greaterThanOrEqualTo(d.decoyMin));
        expect(d.decoyMax, greaterThanOrEqualTo(lastMax));
        lastMax = d.decoyMax;
      }
    });
  });

  group('Generator.generateTuned', () {
    test('returns a clearable board for each tier', () {
      for (final d in Difficulty.tiers) {
        for (var seed = 0; seed < 25; seed++) {
          final p = Generator.generateTuned(
            difficulty: d,
            seed: seed,
            tries: 8,
          );
          // Clearable-by-construction: replaying the groups empties the board.
          var st = GameState.fromPuzzle(p);
          for (final group in p.groups) {
            st = st.submitPath(group);
          }
          expect(st.isWon, isTrue, reason: '${d.id} seed $seed');
        }
      }
    });

    test('is deterministic in (difficulty, seed)', () {
      final a = Generator.generateTuned(difficulty: Difficulty.daily, seed: 20260608);
      final b = Generator.generateTuned(difficulty: Difficulty.daily, seed: 20260608);
      expect(a.initialGrid, b.initialGrid);
      expect(a.target, b.target);
    });
  });
}
