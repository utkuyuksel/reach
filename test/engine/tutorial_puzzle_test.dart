import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/solver.dart';
import 'package:reach/game/tutorial_puzzle.dart';

/// The interactive onboarding relies on the tutorial board being frustration-
/// free: exactly two moves, winnable in any order, with no accidental clears.
/// These guard that contract so a future tweak can't silently break the
/// first-run experience.
void main() {
  final puzzle = tutorialPuzzle();

  group('tutorial puzzle', () {
    test('each construction group is a traceable path summing to the target',
        () {
      final state = GameState.fromPuzzle(puzzle);
      for (final group in puzzle.groups) {
        expect(state.isClearable(group), isTrue,
            reason: 'group $group should be clearable from the start');
        expect(puzzle.initialGrid.sumOfRegion(group), puzzle.target);
      }
    });

    test('replaying the groups in order wins the board', () {
      var state = GameState.fromPuzzle(puzzle);
      for (final group in puzzle.groups) {
        state = state.submitPath(group);
      }
      expect(state.isWon, isTrue);
    });

    test('wins in EITHER clear order (no dead ends)', () {
      var state = GameState.fromPuzzle(puzzle);
      for (final group in puzzle.groups.reversed) {
        state = state.submitPath(group);
      }
      expect(state.isWon, isTrue);
    });

    test('the two groups are the ONLY target-summing paths (no accidental clears)',
        () {
      final paths = Solver.countTargetPaths(
        puzzle.initialGrid,
        puzzle.target,
        maxLen: puzzle.initialGrid.totalCells,
      );
      expect(paths, puzzle.groups.length);
    });
  });
}
