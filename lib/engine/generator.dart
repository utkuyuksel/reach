import 'difficulty.dart';
import 'models/grid.dart';
import 'models/puzzle.dart';
import 'models/tile.dart';
import 'rng.dart';
import 'solver.dart';

/// Seedable, *clearable-by-construction* puzzle generation.
///
/// Pure Dart — no Flutter imports.
///
/// The board is built from a partition: it is carved into connected paths
/// (groups) that together cover every cell exactly once, and each group is
/// given positive values summing to the per-board target. So the whole board
/// can always be cleared — by construction, not by search.
class Generator {
  static const int maxAttempts = 200;
  static const int carveTries = 40;

  static Puzzle generate({
    required Difficulty difficulty,
    required int seed,
  }) {
    assert(difficulty.hasValidTargetRange,
        'Difficulty ${difficulty.id} has no valid target range.');
    final rng = DeterministicRng(seed);
    final rows = difficulty.rows;
    final cols = difficulty.cols;
    final n = rows * cols;

    // Bias the target toward the upper part of the valid range: higher targets
    // mean fewer "accidental" near-target sums (cleaner boards, rarer bounces)
    // and no trivially-low targets.
    final span = difficulty.targetMax - difficulty.targetMin;
    final targetLo = difficulty.targetMin + (span * 2) ~/ 5;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // 1. Per-board target, always above maxValue (no trivial single-tile hit).
      final target = rng.range(targetLo, difficulty.targetMax);

      // 2. Partition the cell count into group sizes in [groupMin, groupMax].
      final sizes = _composeSizes(n, difficulty.groupMin, difficulty.groupMax, rng);
      if (sizes == null) continue; // not possible for valid configs

      // 3. Carve connected paths of those sizes. Random walk for variety, with
      //    a guaranteed snake-order fallback so generation never fails.
      List<List<int>>? paths;
      for (var t = 0; t < carveTries && paths == null; t++) {
        paths = _carveRandom(rows, cols, sizes, rng);
      }
      paths ??= _carveSnake(rows, cols, sizes);

      // 4. Assign values to each group summing to the target.
      final cells = List<Tile?>.filled(n, null);
      final groups = <List<int>>[];
      var nextId = 0;
      for (final path in paths) {
        final values = _assignValues(
          target,
          path.length,
          difficulty.minValue,
          difficulty.maxValue,
          rng,
        );
        for (var j = 0; j < path.length; j++) {
          cells[path[j]] = Tile(id: nextId++, value: values[j]);
        }
        groups.add(List<int>.unmodifiable(path));
      }

      return Puzzle(
        initialGrid: Grid(rows: rows, cols: cols, cells: cells),
        target: target,
        difficulty: difficulty,
        seed: seed,
        groups: groups,
      );
    }
    throw StateError(
      'Generator exhausted $maxAttempts attempts for ${difficulty.id} '
      '(seed $seed).',
    );
  }

  /// Like [generate], but biases toward the difficulty's decoy band (false-lead
  /// density) by trying a deterministic sequence of seeds and picking the first
  /// board in band — or the closest if none qualifies within [tries]. Every
  /// candidate is still clearable-by-construction, so this only affects *how
  /// hard* the board feels, never solvability. Deterministic in (difficulty,
  /// seed), so the Daily stays reproducible.
  static Puzzle generateTuned({
    required Difficulty difficulty,
    required int seed,
    int tries = 14,
  }) {
    Puzzle? best;
    var bestDistance = 1 << 30;
    for (var i = 0; i < tries; i++) {
      final puzzle = generate(difficulty: difficulty, seed: seed + i * 1000003);
      final paths = Solver.countTargetPaths(
        puzzle.initialGrid,
        puzzle.target,
        maxLen: difficulty.groupMax,
      );
      final decoys = paths - puzzle.groupCount;
      if (decoys >= difficulty.decoyMin && decoys <= difficulty.decoyMax) {
        return puzzle;
      }
      final distance = decoys < difficulty.decoyMin
          ? difficulty.decoyMin - decoys
          : decoys - difficulty.decoyMax;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = puzzle;
      }
    }
    return best!;
  }

  /// Decorate [puzzle] with modifier tiles — applied AFTER the solvable
  /// partition is carved, so values, groups, and solvability are untouched.
  /// Deterministic in `puzzle.seed`: the same board always decorates the same
  /// way. Gold and veiled cells are disjoint; counts are clamped to the board.
  static Puzzle decorate(
    Puzzle puzzle, {
    int veiled = 0,
    int gold = 0,
    int locked = 0,
  }) {
    if (veiled <= 0 && gold <= 0 && locked <= 0) return puzzle;
    final grid = puzzle.initialGrid;
    final rng = DeterministicRng(puzzle.seed ^ 0x5DEC0);

    // Deterministic Fisher–Yates over the occupied cells.
    final cells = grid.occupiedIndices();
    for (var i = cells.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = cells[i];
      cells[i] = cells[j];
      cells[j] = t;
    }

    final goldCount = gold.clamp(0, cells.length);
    final veilCount = veiled.clamp(0, cells.length - goldCount);
    final goldSet = cells.take(goldCount).toSet();
    final veilSet = cells.skip(goldCount).take(veilCount).toSet();

    // Locked placement is VALIDATED so a freeing order always exists:
    // a lock may only sit on a cell with an orthogonal neighbour in a
    // DIFFERENT group that itself contains no lock (clearing that lock-free
    // neighbour group opens this lock). One lock per group, never on
    // gold/veiled cells.
    final groupOf = <int, int>{};
    for (var g = 0; g < puzzle.groups.length; g++) {
      for (final i in puzzle.groups[g]) {
        groupOf[i] = g;
      }
    }
    final lockedGroups = <int>{};
    final lockSet = <int>{};
    if (locked > 0) {
      for (final cell in cells) {
        if (lockSet.length >= locked) break;
        if (goldSet.contains(cell) || veilSet.contains(cell)) continue;
        final g = groupOf[cell]!;
        if (lockedGroups.contains(g)) continue;
        final hasFreeKey = grid.neighborsOf(cell).any((n) {
          final ng = groupOf[n];
          return ng != null && ng != g && !lockedGroups.contains(ng);
        });
        if (!hasFreeKey) continue;
        lockSet.add(cell);
        lockedGroups.add(g);
      }
    }

    final newCells = List<Tile?>.from(grid.cells);
    void apply(Set<int> set, TileModifier m) {
      for (final i in set) {
        final t = newCells[i]!;
        newCells[i] = Tile(id: t.id, value: t.value, modifier: m);
      }
    }

    apply(goldSet, TileModifier.gold);
    apply(veilSet, TileModifier.veiled);
    apply(lockSet, TileModifier.locked);

    return Puzzle(
      initialGrid: Grid(rows: grid.rows, cols: grid.cols, cells: newCells),
      target: puzzle.target,
      difficulty: puzzle.difficulty,
      seed: puzzle.seed,
      groups: puzzle.groups,
    );
  }

  /// Partition [total] into parts each in [gmin, gmax], never leaving a
  /// remainder smaller than [gmin]. Returns null if impossible.
  static List<int>? _composeSizes(
    int total,
    int gmin,
    int gmax,
    DeterministicRng rng,
  ) {
    final sizes = <int>[];
    var rem = total;
    while (rem > 0) {
      final hi = rem < gmax ? rem : gmax;
      final candidates = <int>[];
      for (var s = gmin; s <= hi; s++) {
        if (rem - s == 0 || rem - s >= gmin) candidates.add(s);
      }
      if (candidates.isEmpty) return null;
      final s = candidates[rng.nextInt(candidates.length)];
      sizes.add(s);
      rem -= s;
    }
    return sizes;
  }

  /// Carve connected paths of the given [sizes] by random self-avoiding walks,
  /// starting each from the most-constrained uncovered cell. Returns null if a
  /// walk gets stuck (caller retries or falls back to the snake carve).
  static List<List<int>>? _carveRandom(
    int rows,
    int cols,
    List<int> sizes,
    DeterministicRng rng,
  ) {
    final n = rows * cols;
    final covered = List<bool>.filled(n, false);
    final paths = <List<int>>[];

    List<int> neighbors(int i) {
      final r = i ~/ cols;
      final c = i % cols;
      final out = <int>[];
      if (r > 0) out.add(i - cols);
      if (r < rows - 1) out.add(i + cols);
      if (c > 0) out.add(i - 1);
      if (c < cols - 1) out.add(i + 1);
      return out;
    }

    int uncoveredNeighborCount(int i) =>
        neighbors(i).where((nb) => !covered[nb]).length;

    int? mostConstrainedStart() {
      var best = -1;
      var bestCount = 1 << 30;
      final ties = <int>[];
      for (var i = 0; i < n; i++) {
        if (covered[i]) continue;
        final c = uncoveredNeighborCount(i);
        if (c < bestCount) {
          bestCount = c;
          best = i;
          ties
            ..clear()
            ..add(i);
        } else if (c == bestCount) {
          ties.add(i);
        }
      }
      if (best < 0) return null;
      return ties[rng.nextInt(ties.length)];
    }

    for (final size in sizes) {
      final start = mostConstrainedStart();
      if (start == null) return null;
      final path = <int>[start];
      covered[start] = true;
      while (path.length < size) {
        final free = neighbors(path.last).where((nb) => !covered[nb]).toList();
        if (free.isEmpty) return null; // stuck
        final next = free[rng.nextInt(free.length)];
        path.add(next);
        covered[next] = true;
      }
      paths.add(path);
    }
    return paths;
  }

  /// Guaranteed carve: split a boustrophedon (snake) traversal — itself a
  /// Hamiltonian path of the grid — into consecutive runs of the given sizes.
  /// Every run is therefore a connected path.
  static List<List<int>> _carveSnake(int rows, int cols, List<int> sizes) {
    final order = <int>[];
    for (var r = 0; r < rows; r++) {
      if (r.isEven) {
        for (var c = 0; c < cols; c++) {
          order.add(r * cols + c);
        }
      } else {
        for (var c = cols - 1; c >= 0; c--) {
          order.add(r * cols + c);
        }
      }
    }
    final paths = <List<int>>[];
    var idx = 0;
    for (final size in sizes) {
      paths.add(order.sublist(idx, idx + size));
      idx += size;
    }
    return paths;
  }

  /// [k] positive values in [minValue, maxValue] summing to [target].
  static List<int> _assignValues(
    int target,
    int k,
    int minValue,
    int maxValue,
    DeterministicRng rng,
  ) {
    final values = List<int>.filled(k, minValue);
    var extra = target - k * minValue; // >= 0 for valid configs
    while (extra > 0) {
      final avail = <int>[];
      for (var i = 0; i < k; i++) {
        if (values[i] < maxValue) avail.add(i);
      }
      final i = avail[rng.nextInt(avail.length)];
      values[i]++;
      extra--;
    }
    return values;
  }

  /// Deterministic Daily seed from a local date: the integer `YYYYMMDD`.
  static int dailySeed(DateTime localDate) =>
      localDate.year * 10000 + localDate.month * 100 + localDate.day;
}
