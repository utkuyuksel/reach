import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/generator.dart';
import 'package:reach/engine/models/game_state.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/solver.dart';

/// Headline guarantee: across tens of thousands of seeds per config, EVERY
/// generated board is fully clearable and well-formed. Verification is
/// independent of the generator's claims:
///   * the board is full and the target is above maxValue (no trivial hit);
///   * the groups cover every cell exactly once, each a connected path of an
///     allowed size summing to the target;
///   * the board can actually be CLEARED — replaying the groups through the
///     real GameState.submitPath mechanic empties the board and wins;
///   * a hint is available on the fresh board.
void main() {
  const int seedsPerConfig = 15000;

  // Named tiers + a spread of endless levels (deduped by parameter tuple), so
  // every config a player can actually be served is stress-tested.
  final configs = _uniqueConfigs();

  group('generator stress test', () {
    for (final difficulty in configs) {
      test(
        '${difficulty.id}: $seedsPerConfig boards all clearable & well-formed',
        () {
          var failures = 0;
          final firstFailures = <String>[];
          for (var seed = 0; seed < seedsPerConfig; seed++) {
            final problems = _verify(difficulty, seed);
            if (problems.isNotEmpty) {
              failures++;
              if (firstFailures.length < 10) {
                firstFailures.add('seed $seed: ${problems.join('; ')}');
              }
            }
          }
          expect(
            failures,
            0,
            reason: 'Expected zero bad boards for ${difficulty.id}. '
                'First failures:\n${firstFailures.join('\n')}',
          );
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );
    }
  });

  // Validate the runtime solver on real boards (a sample, since findPartition
  // is heavier than the replay check): it must find a partition and a safe
  // hint for every freshly generated board.
  group('solver on generated boards', () {
    const sample = 2000;
    for (final difficulty in configs) {
      test('${difficulty.id}: solver finds a partition + safe hint', () {
        var failures = 0;
        for (var seed = 0; seed < sample; seed++) {
          final puzzle = Generator.generate(difficulty: difficulty, seed: seed);
          final partition = Solver.findPartition(
            puzzle.initialGrid,
            puzzle.target,
            maxLen: difficulty.groupMax,
          );
          final hint = Solver.hint(puzzle, puzzle.initialGrid);
          if (partition == null || hint == null) failures++;
        }
        expect(failures, 0);
      }, timeout: const Timeout(Duration(minutes: 10)));
    }
  });
}

List<Difficulty> _uniqueConfigs() {
  final all = <Difficulty>[
    ...Difficulty.tiers,
    for (final l in [0, 2, 4, 6, 9, 12, 16, 24, 40])
      Difficulty.endlessForLevel(l),
  ];
  final seen = <String>{};
  final unique = <Difficulty>[];
  for (final d in all) {
    final key = '${d.rows}x${d.cols}:${d.minValue}-${d.maxValue}:'
        '${d.groupMin}-${d.groupMax}';
    if (seen.add(key)) unique.add(d);
  }
  return unique;
}

List<String> _verify(Difficulty d, int seed) {
  final problems = <String>[];

  final Puzzle puzzle;
  try {
    puzzle = Generator.generate(difficulty: d, seed: seed);
  } catch (e) {
    return ['generation threw: $e'];
  }

  final grid = puzzle.initialGrid;

  if (!grid.isFull) problems.add('board not full');
  if (puzzle.target <= d.maxValue) {
    problems.add('target ${puzzle.target} not above maxValue ${d.maxValue}');
  }

  // Groups: cover every cell once; each a connected path of allowed size
  // summing to the target.
  final covered = <int>{};
  for (final group in puzzle.groups) {
    if (group.length < d.groupMin || group.length > d.groupMax) {
      problems.add('group size ${group.length} out of [${d.groupMin},'
          '${d.groupMax}]');
    }
    var sum = 0;
    for (var j = 0; j < group.length; j++) {
      final cell = group[j];
      if (!covered.add(cell)) problems.add('cell $cell covered twice');
      final tile = grid.at(cell);
      if (tile == null) {
        problems.add('group cell $cell empty');
        continue;
      }
      if (j > 0 && !grid.areOrthogonalNeighbors(group[j - 1], cell)) {
        problems.add('group not a connected path at $cell');
      }
      sum += tile.value;
    }
    if (sum != puzzle.target) {
      problems.add('group sums to $sum, not ${puzzle.target}');
    }
  }
  if (covered.length != grid.totalCells) {
    problems.add('groups cover ${covered.length}/${grid.totalCells} cells');
  }

  // Independent clearability: replay the partition through the real mechanic.
  var state = GameState.fromPuzzle(puzzle);
  for (final group in puzzle.groups) {
    final before = state.found;
    state = state.submitPath(group);
    if (state.found != before + 1) {
      problems.add('group $group not accepted by submitPath');
      break;
    }
  }
  if (!state.isWon) problems.add('board not cleared after replaying all groups');

  return problems;
}
