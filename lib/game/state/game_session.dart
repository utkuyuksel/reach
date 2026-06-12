import '../../engine/models/game_state.dart';
import '../../engine/models/puzzle.dart';

enum GameMode {
  daily,
  zen,

  /// A past Daily replayed from the calendar/archive: fills the calendar
  /// (medal credit) but never touches the streak; reduced coin reward.
  archive,

  /// A Daily Ladder bonus board (easy/hard tier of today's date): a second
  /// and third daily habit point. Never touches the streak or the medal —
  /// the Medium Daily stays the one canonical shared board.
  ladder,
}

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

  /// 'YYYY-MM-DD' key for Daily/archive sessions; null for Zen.
  final String? dateKey;

  /// Zen chapter finale (the 10th board of a chapter): pays double and closes
  /// the chapter. Marked with a small gem on the game screen.
  final bool isFinale;

  /// A hand-crafted modifier INTRO level: the game screen coaches the player
  /// through it with the tutorial's gliding finger.
  final bool isIntro;

  /// Total coins granted for this board's win (clear + bonuses), set by the
  /// controller at win time so the UI never re-derives economy math.
  final int coinsEarned;

  const GameSession({
    required this.mode,
    required this.puzzle,
    required this.state,
    this.hintCells = const [],
    this.hintsUsed = 0,
    this.wrongTraces = 0,
    this.stuck = false,
    this.dateKey,
    this.isFinale = false,
    this.isIntro = false,
    this.coinsEarned = 0,
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
    int? coinsEarned,
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
        isFinale: isFinale,
        isIntro: isIntro,
        coinsEarned: coinsEarned ?? this.coinsEarned,
      );
}
