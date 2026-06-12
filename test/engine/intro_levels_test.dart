import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/models/tile.dart';
import 'package:reach/engine/solver.dart';
import 'package:reach/game/intro_levels.dart';

/// Intro levels are the first impression of every modifier — they must be
/// frustration-proof: solvable in coached order, no accidental paths, and
/// each one must actually demonstrate its lesson.
void main() {
  test('regular levels have no intro', () {
    expect(introPuzzleForLevel(1), isNull);
    expect(introPuzzleForLevel(12), isNull);
    expect(introPuzzleForLevel(60), isNull);
  });

  test('every intro level solves in coached order (top row, then bottom)',
      () {
    for (final level in kIntroLevels.keys) {
      final p = introPuzzleForLevel(level)!;
      var s = GameState.fromPuzzle(p);
      for (final g in p.groups) {
        s = s.submitPath(g);
      }
      expect(s.isWon, isTrue, reason: 'intro $level failed');
    }
  });

  test('gold intro carries exactly one gold tile', () {
    final p = introPuzzleForLevel(11)!;
    final golds = p.initialGrid.cells
        .where((t) => t?.modifier == TileModifier.gold)
        .length;
    expect(golds, 1);
  });

  test('veiled intro: clearing the visible row lifts the whole fog', () {
    final p = introPuzzleForLevel(21)!;
    var s = GameState.fromPuzzle(p);
    s = s.submitPath(const [0, 1, 2]);
    for (final i in const [3, 4, 5]) {
      expect(s.grid.at(i)!.modifier, TileModifier.none,
          reason: 'cell $i still veiled');
    }
  });

  test('locked intro: the gated row opens only after the key row clears', () {
    final p = introPuzzleForLevel(31)!;
    var s = GameState.fromPuzzle(p);
    expect(s.isClearable(const [3, 4, 5]), isFalse); // locked
    s = s.submitPath(const [0, 1, 2]);
    expect(s.isClearable(const [3, 4, 5]), isTrue); // freed
  });

  test('wild intro: the ✦ absorbs the missing value on the coached path', () {
    final p = introPuzzleForLevel(61)!;
    final s = GameState.fromPuzzle(p);
    expect(p.initialGrid.at(1)!.modifier, TileModifier.wild);
    expect(s.isClearable(const [0, 1, 2]), isTrue); // 4 + ✦ + 3
  });

  test('no accidental paths: the two rows are the only clears', () {
    for (final level in kIntroLevels.keys) {
      final p = introPuzzleForLevel(level)!;
      final paths = Solver.countTargetPaths(
        p.initialGrid,
        p.target,
        maxLen: p.initialGrid.totalCells,
      );
      expect(paths, 2, reason: 'intro $level has decoys');
    }
  });
}
