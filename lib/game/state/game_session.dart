import '../../engine/models/game_state.dart';
import '../../engine/models/puzzle.dart';

enum GameMode { daily, zen }

/// The full state of one playable session: the puzzle, the live [GameState],
/// the mode, the current hint highlight, and how many hints were used.
/// Immutable — the controller replaces it on every change.
class GameSession {
  final GameMode mode;
  final Puzzle puzzle;
  final GameState state;

  /// Cells highlighted by an active hint (one group), or empty.
  final List<int> hintCells;

  /// Hints used this board (for the spoiler-free Daily share + stats).
  final int hintsUsed;

  /// Wrong (invalid-sum / non-path) attempts this board — drives the
  /// efficiency star rating.
  final int wrongTraces;

  /// No moves remain but the board isn't clear (the player played into a dead
  /// end, peg-solitaire style); the UI shows a gentle undo/restart prompt.
  final bool stuck;

  /// 'YYYY-MM-DD' key for Daily sessions; null for Zen.
  final String? dateKey;

  const GameSession({
    required this.mode,
    required this.puzzle,
    required this.state,
    this.hintCells = const [],
    this.hintsUsed = 0,
    this.wrongTraces = 0,
    this.stuck = false,
    this.dateKey,
  });

  int get target => puzzle.target;
  int get found => state.found;
  int get totalGroups => state.totalGroups;
  bool get isWon => state.isWon;

  GameSession copyWith({
    GameState? state,
    List<int>? hintCells,
    int? hintsUsed,
    int? wrongTraces,
    bool? stuck,
  }) =>
      GameSession(
        mode: mode,
        puzzle: puzzle,
        state: state ?? this.state,
        hintCells: hintCells ?? this.hintCells,
        hintsUsed: hintsUsed ?? this.hintsUsed,
        wrongTraces: wrongTraces ?? this.wrongTraces,
        stuck: stuck ?? this.stuck,
        dateKey: dateKey,
      );
}
