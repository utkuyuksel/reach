import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../engine/generator.dart';
import '../../engine/models/game_state.dart';
import '../../engine/models/puzzle.dart';
import '../../engine/models/tile.dart';
import '../../engine/solver.dart';
import '../../services/analytics_service.dart';
import '../../util/date_key.dart';
import '../intro_levels.dart';
import 'daily_controller.dart';
import 'game_session.dart';
import 'mosaic_controller.dart';
import 'providers.dart';
import 'stats_controller.dart';
import 'wallet_controller.dart';
import 'zen_controller.dart';

/// Drives the active [GameSession]: starts boards, routes traced groups to the
/// engine, tracks rejected attempts (for stars), and on a clear awards coins +
/// records Daily/Zen/archive + emits analytics. UI concerns (ads, share, hint
/// cost, drag) live in the screen/widgets.
class GameController extends Notifier<GameSession?> {
  bool _winRecorded = false;

  /// Set when the player hits a dead end this board (mercy signal). Survives
  /// undo BY DESIGN: undoing out of a dead end doesn't erase the fact the
  /// player struggled — that's exactly when the next boards should ease.
  bool _sawStuck = false;

  /// Invisible difficulty director: >0 ⇒ the next N Zen boards sit at the
  /// gentle end of their decoy band (Block Blast-style mercy — no UI, no
  /// monetization coupling).
  int _mercyBoards = 0;

  @override
  GameSession? build() => null;

  void startWithPuzzle(
    Puzzle puzzle,
    GameMode mode, {
    String? dateKey,
    bool isFinale = false,
    bool isIntro = false,
  }) {
    _winRecorded = false;
    _sawStuck = false;
    state = GameSession(
      mode: mode,
      puzzle: puzzle,
      state: GameState.fromPuzzle(puzzle),
      dateKey: dateKey,
      isFinale: isFinale,
      isIntro: isIntro,
    );
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.boardStart, {
      'mode': mode.name,
      'difficulty': puzzle.difficulty.id,
      'target': puzzle.target,
      'groups': puzzle.groupCount,
      'finale': isFinale,
    });
  }

  void startDaily() {
    final now = DateTime.now();
    final puzzle = Generator.generateTuned(
      difficulty: Difficulty.daily,
      seed: Generator.dailySeed(now),
    );
    startWithPuzzle(puzzle, GameMode.daily, dateKey: dateKeyFor(now));
  }

  /// Replay a past Daily from the calendar/archive. Same board everyone saw
  /// that day (deterministic seed); never touches the streak.
  void startArchive(DateTime date) {
    final puzzle = Generator.generateTuned(
      difficulty: Difficulty.daily,
      seed: Generator.dailySeed(date),
    );
    startWithPuzzle(puzzle, GameMode.archive, dateKey: dateKeyFor(date));
  }

  /// Start a Daily Ladder tier for [date]: the easy or hard sibling of that
  /// day's canonical board. Deterministic per (date, tier), like the Daily.
  void startLadder(DateTime date, {required bool hard}) {
    final puzzle = Generator.generateTuned(
      difficulty: hard ? Difficulty.dailyHard : Difficulty.dailyEasy,
      seed: Generator.dailySeed(date) * 3 + (hard ? 2 : 1),
    );
    startWithPuzzle(
      puzzle,
      GameMode.ladder,
      dateKey: '${dateKeyFor(date)}#${hard ? 'h' : 'e'}',
    );
  }

  void startZen() {
    final cleared = ref.read(zenControllerProvider).boardsCleared;

    // A modifier's debut level is a hand-crafted, coached intro board
    // (industry standard: every new obstacle gets one guided level).
    final intro = introPuzzleForLevel(cleared + 1);
    if (intro != null) {
      startWithPuzzle(intro, GameMode.zen, isIntro: true);
      return;
    }

    final base = Difficulty.endlessForLevel(cleared);
    final position = cleared % Difficulty.clearsPerLevel; // 0..9 in chapter
    final isFinale = position == Difficulty.clearsPerLevel - 1;
    final difficulty = _modulated(base, position, isFinale);
    var puzzle = Generator.generateTuned(
        difficulty: difficulty, seed: _levelSeed(cleared + 1));
    puzzle = Generator.decorate(
      puzzle,
      gold: _goldFor(cleared, isFinale, puzzle.seed),
      veiled: _veiledFor(cleared, puzzle.seed),
      locked: _lockedFor(cleared),
      wild: _wildFor(cleared, isFinale, puzzle.seed),
    );
    startWithPuzzle(puzzle, GameMode.zen, isFinale: isFinale);
  }

  /// Modifier schedule — one new type per chapter, gently (the Toon Blast
  /// rollout lesson). Gold from chapter 2: every finale + ~every 3rd board.
  int _goldFor(int cleared, bool isFinale, int seed) {
    final chapter = cleared ~/ Difficulty.clearsPerLevel + 1;
    if (chapter < 2) return 0;
    if (isFinale) return 1 + (chapter >= 5 ? 1 : 0);
    return seed % 3 == 0 ? 1 : 0;
  }

  /// Veiled tiles from chapter 3, scaling slowly with the chapter and never
  /// fogging more than a small corner of the board.
  int _veiledFor(int cleared, int seed) {
    final chapter = cleared ~/ Difficulty.clearsPerLevel + 1;
    if (chapter < 3) return 0;
    final base = 2 + ((chapter - 3) ~/ 2);
    return (base + seed % 2).clamp(2, 6);
  }

  /// Locked tiles from chapter 4 (one), two from chapter 6 — the sequencing
  /// layer arrives last, after gold and veil are familiar.
  int _lockedFor(int cleared) {
    final chapter = cleared ~/ Difficulty.clearsPerLevel + 1;
    if (chapter < 4) return 0;
    return chapter >= 6 ? 2 : 1;
  }

  /// The wildcard arrives last (chapter 7+): every finale, and roughly every
  /// other board in between — one relief valve per board, never two.
  int _wildFor(int cleared, bool isFinale, int seed) {
    final chapter = cleared ~/ Difficulty.clearsPerLevel + 1;
    if (chapter < 7) return 0;
    return (isFinale || seed % 2 == 0) ? 1 : 0;
  }

  void nextZen() => startZen();

  /// Sawtooth pacing within a chapter + the invisible mercy director, applied
  /// as a shift of the decoy band passed to the generator. Difficulty rises
  /// through the chapter, eases on the two breather boards, and peaks on the
  /// finale — and quietly floors after struggle signals.
  Difficulty _modulated(Difficulty base, int position, bool isFinale) {
    final span = base.decoyMax - base.decoyMin;
    if (span <= 2) return base;

    int lo, hi;
    if (_mercyBoards > 0) {
      _mercyBoards--;
      lo = base.decoyMin;
      hi = base.decoyMin + span ~/ 3; // gentle floor
    } else if (isFinale) {
      lo = base.decoyMax - span ~/ 3; // chapter peak
      hi = base.decoyMax;
    } else if (position >= 7) {
      lo = base.decoyMin; // breathers before the finale
      hi = base.decoyMin + span ~/ 3;
    } else {
      // Rising stretch: slide a third-wide window up the band.
      final t = position / 6.0;
      lo = base.decoyMin + (t * (span * 2 / 3)).round();
      hi = lo + span ~/ 3;
    }
    if (hi > base.decoyMax) hi = base.decoyMax;
    if (lo > hi) lo = hi;

    return Difficulty(
      id: base.id,
      rows: base.rows,
      cols: base.cols,
      minValue: base.minValue,
      maxValue: base.maxValue,
      groupMin: base.groupMin,
      groupMax: base.groupMax,
      decoyMin: lo,
      decoyMax: hi,
    );
  }

  /// Try to clear a traced [path]. Returns true if it cleared a group. A wrong
  /// sum or a board-stranding move returns false (counted as a wrong trace, no
  /// penalty beyond stars). Awards coins + records the clear on a win.
  bool submitPath(List<int> path) {
    final session = state;
    if (session == null) return false;
    final next = session.state.submitPath(path);
    if (identical(next, session.state)) {
      if (path.length >= 2) {
        state = session.copyWith(wrongTraces: session.wrongTraces + 1);
      }
      return false;
    }
    final stuck = !next.hasMove;
    if (stuck && !next.isWon) _sawStuck = true;
    final updated = session.copyWith(
      state: next,
      hintCells: const [],
      // Peg-solitaire style: only flag "stuck" when NO move remains — never
      // warn the instant the board becomes unwinnable.
      stuck: stuck,
    );
    state = updated;
    if (next.isWon && !_winRecorded) {
      _winRecorded = true;
      final earned = _onWin(updated);
      state = updated.copyWith(coinsEarned: earned);
    }
    return true;
  }

  void undo() {
    final session = state;
    if (session == null) return;
    _winRecorded = false;
    state = session.copyWith(
      state: session.state.undo(),
      hintCells: const [],
      stuck: false,
    );
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.undo);
  }

  /// Safe Rewind: walk the undo history back to the most recent state from
  /// which the board can still be fully cleared. The escape hatch for a dead
  /// end without tapping undo six times (rewarded-ad gated for free players;
  /// a Premium perk otherwise). Returns the number of steps rewound (0 = the
  /// current state is already safe).
  int rewindToSafe() {
    final session = state;
    if (session == null || session.isWon) return 0;
    final maxLen = session.puzzle.difficulty.groupMax;
    var s = session.state;
    var steps = 0;
    while (s.canUndo &&
        !Solver.isSolvable(s.grid, s.target, maxLen: maxLen)) {
      s = s.undo();
      steps++;
    }
    if (steps == 0) return 0;
    _winRecorded = false;
    state = session.copyWith(state: s, hintCells: const [], stuck: false);
    ref.read(analyticsServiceProvider).log(
      AnalyticsEvents.safeRewind,
      {'steps': steps, 'mode': session.mode.name},
    );
    return steps;
  }

  void restart() {
    final session = state;
    if (session == null) return;
    _winRecorded = false;
    state = GameSession(
      mode: session.mode,
      puzzle: session.puzzle,
      state: session.state.restart(),
      dateKey: session.dateKey,
      isFinale: session.isFinale,
    );
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.restart);
  }

  /// Reveal a hint (caller handles the coin/ad cost). Returns true if shown.
  bool revealHint() {
    final session = state;
    if (session == null || session.isWon) return false;
    final group = Solver.hint(session.puzzle, session.state.grid);
    if (group == null) return false;
    state = session.copyWith(
      hintCells: group,
      hintsUsed: session.hintsUsed + 1,
    );
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.hintShown, {
      'mode': session.mode.name,
      'hintsUsed': session.hintsUsed + 1,
    });
    return true;
  }

  /// Efficiency stars for the just-won board.
  int starsFor(GameSession session) =>
      ref.read(gameConfigProvider).starsForWrong(session.wrongTraces);

  /// Awards coins, records progress, and returns the total coins earned.
  int _onWin(GameSession session) {
    final config = ref.read(gameConfigProvider);
    final wallet = ref.read(walletControllerProvider.notifier);
    final analytics = ref.read(analyticsServiceProvider);
    final stars = config.starsForWrong(session.wrongTraces);
    final cleanBadge = session.hintsUsed == 0; // the "clean" badge
    final flowClean = cleanBadge && session.wrongTraces == 0; // chain rule

    // Date-keyed modes pay only for a FRESH record — replaying a completed
    // day (restart-after-win, archive re-entry) must never re-mint coins.
    var earned = 0;
    var freshWin = true; // false when a date-keyed board was already complete
    switch (session.mode) {
      case GameMode.daily:
        final fresh = !ref
            .read(dailyControllerProvider)
            .isCompleted(session.dateKey!);
        ref.read(dailyControllerProvider.notifier).recordCompletion(
              dateKey: session.dateKey!,
              hintsUsed: session.hintsUsed,
              stars: stars,
            );
        freshWin = fresh;
        if (fresh) {
          earned = config.coinsPerClear + config.dailyClearBonus;
          analytics.log(AnalyticsEvents.dailyCompleted, {
            'stars': stars,
            'hintsUsed': session.hintsUsed,
          });
          ref.read(statsControllerProvider.notifier).recordWin(
                clean: cleanBadge,
                threeStarDaily: stars == 3,
              );
        }

      case GameMode.archive:
        final fresh = ref
            .read(dailyControllerProvider.notifier)
            .recordArchiveCompletion(
              dateKey: session.dateKey!,
              hintsUsed: session.hintsUsed,
              stars: stars,
            );
        freshWin = fresh;
        if (fresh) {
          earned = config.archiveClearCoins;
          analytics.log(AnalyticsEvents.archivePlayed, {'stars': stars});
          ref
              .read(statsControllerProvider.notifier)
              .recordWin(clean: cleanBadge);
        }

      case GameMode.ladder:
        final hard = session.dateKey!.endsWith('#h');
        final fresh = ref
            .read(dailyControllerProvider.notifier)
            .recordLadderCompletion(
              ladderKey: session.dateKey!,
              hintsUsed: session.hintsUsed,
              stars: stars,
            );
        freshWin = fresh;
        if (fresh) {
          earned = hard ? config.ladderHardCoins : config.ladderEasyCoins;
          ref
              .read(statsControllerProvider.notifier)
              .recordWin(clean: cleanBadge);
        }

      case GameMode.zen:
        final zen = ref.read(zenControllerProvider.notifier);
        final cleared = zen.recordClear(clean: flowClean);
        earned = config.coinsPerClear * (session.isFinale ? 2 : 1);

        // Gold tiles: a full clear collects every gold on the board.
        final goldTiles = session.puzzle.initialGrid.cells
            .where((t) => t != null && t.modifier == TileModifier.gold)
            .length;
        earned += goldTiles * config.goldTileCoins;

        // Chapter chest: the finale's clear closes the chapter.
        if (cleared % Difficulty.clearsPerLevel == 0) {
          earned += config.chapterBonus;
          analytics.log(AnalyticsEvents.chapterComplete, {
            'chapter': cleared ~/ Difficulty.clearsPerLevel,
          });
        }

        // Flow-chain milestones (paid once, at exactly the milestone length).
        final chain = ref.read(zenControllerProvider).chain;
        final milestone = switch (chain) {
          3 => config.chainMilestone1,
          7 => config.chainMilestone2,
          15 => config.chainMilestone3,
          _ => 0,
        };
        if (milestone > 0) {
          earned += milestone;
          analytics.log(AnalyticsEvents.chainMilestone, {'chain': chain});
        }

        // Mercy director: struggle on this board eases the next two.
        if (session.wrongTraces >= 3 || _sawStuck) _mercyBoards = 2;

        ref.read(statsControllerProvider.notifier).recordWin(clean: cleanBadge);
    }

    // Every fresh clear, in any mode, reveals a few cells of this week's
    // mosaic — the cross-mode habit-stacking hook. Finishing the artwork
    // pays its weekly chest right into this win.
    if (freshWin) {
      earned +=
          ref.read(mosaicControllerProvider.notifier).onBoardCleared();
    }

    wallet.earn(earned, reason: 'clear');
    analytics.log(AnalyticsEvents.boardClear, {
      'mode': session.mode.name,
      'difficulty': session.puzzle.difficulty.id,
      'groups': session.totalGroups,
      'wrongTraces': session.wrongTraces,
      'hintsUsed': session.hintsUsed,
      'stars': stars,
      'coinsEarned': earned,
    });
    return earned;
  }

  /// Deterministic seed for Zen level N: the SAME Level 5 for every player,
  /// every device, forever ("level 23'te takıldım" is a shared experience,
  /// and future level-keyed content/leaderboards stay possible). The only
  /// per-player variance is the invisible mercy director, which may serve a
  /// struggling player a gentler VARIANT of the level.
  int _levelSeed(int level) =>
      (0x2EAC4 ^ (level * 0x9E3779B97F4A7C15)) & 0x7FFFFFFFFFFFFFFF;
}

final gameControllerProvider =
    NotifierProvider<GameController, GameSession?>(GameController.new);
