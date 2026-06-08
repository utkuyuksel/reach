import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../engine/generator.dart';
import '../../engine/models/game_state.dart';
import '../../engine/models/puzzle.dart';
import '../../engine/solver.dart';
import '../../services/analytics_service.dart';
import '../../util/date_key.dart';
import 'daily_controller.dart';
import 'game_session.dart';
import 'providers.dart';
import 'wallet_controller.dart';
import 'zen_controller.dart';

/// Drives the active [GameSession]: starts boards, routes traced groups to the
/// engine, tracks rejected attempts (for stars), and on a clear awards coins +
/// records Daily/Zen + emits analytics. UI concerns (ads, share, hint cost,
/// drag) live in the screen/widgets.
class GameController extends Notifier<GameSession?> {
  int _zenNonce = 0;
  bool _winRecorded = false;

  @override
  GameSession? build() => null;

  void startWithPuzzle(Puzzle puzzle, GameMode mode, {String? dateKey}) {
    _winRecorded = false;
    state = GameSession(
      mode: mode,
      puzzle: puzzle,
      state: GameState.fromPuzzle(puzzle),
      dateKey: dateKey,
    );
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.boardStart, {
      'mode': mode.name,
      'difficulty': puzzle.difficulty.id,
      'target': puzzle.target,
      'groups': puzzle.groupCount,
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

  void startZen() {
    final cleared = ref.read(zenControllerProvider).boardsCleared;
    final difficulty = Difficulty.endlessForLevel(cleared);
    final puzzle =
        Generator.generateTuned(difficulty: difficulty, seed: _freshSeed());
    startWithPuzzle(puzzle, GameMode.zen);
  }

  void nextZen() => startZen();

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
    final updated = session.copyWith(
      state: next,
      hintCells: const [],
      // Peg-solitaire style: only flag "stuck" when NO move remains — never
      // warn the instant the board becomes unwinnable.
      stuck: !next.hasMove,
    );
    state = updated;
    if (next.isWon && !_winRecorded) {
      _winRecorded = true;
      _onWin(updated);
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

  void restart() {
    final session = state;
    if (session == null) return;
    _winRecorded = false;
    state = GameSession(
      mode: session.mode,
      puzzle: session.puzzle,
      state: session.state.restart(),
      dateKey: session.dateKey,
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

  void _onWin(GameSession session) {
    final config = ref.read(gameConfigProvider);
    final wallet = ref.read(walletControllerProvider.notifier);
    final stars = config.starsForWrong(session.wrongTraces);

    var earned = config.coinsPerClear;
    if (session.mode == GameMode.daily && session.dateKey != null) {
      earned += config.dailyClearBonus;
      ref.read(dailyControllerProvider.notifier).recordCompletion(
            dateKey: session.dateKey!,
            hintsUsed: session.hintsUsed,
            stars: stars,
          );
      ref.read(analyticsServiceProvider).log(AnalyticsEvents.dailyCompleted, {
        'stars': stars,
        'hintsUsed': session.hintsUsed,
      });
    } else if (session.mode == GameMode.zen) {
      ref.read(zenControllerProvider.notifier).recordClear();
    }

    wallet.earn(earned, reason: 'clear');
    ref.read(analyticsServiceProvider).log(AnalyticsEvents.boardClear, {
      'mode': session.mode.name,
      'difficulty': session.puzzle.difficulty.id,
      'groups': session.totalGroups,
      'wrongTraces': session.wrongTraces,
      'hintsUsed': session.hintsUsed,
      'stars': stars,
      'coinsEarned': earned,
    });
  }

  int _freshSeed() {
    _zenNonce++;
    final base = DateTime.now().microsecondsSinceEpoch;
    return (base ^ (_zenNonce * 0x9E3779B1)) & 0x7FFFFFFFFFFFFFFF;
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameSession?>(GameController.new);
