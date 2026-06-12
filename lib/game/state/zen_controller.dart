import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../services/persisted_models.dart';
import 'providers.dart';

/// Tracks Zen progress: total boards cleared (drives the difficulty ramp and
/// the displayed chapter) and the flow chain (consecutive clean clears).
class ZenController extends Notifier<ZenRecord> {
  @override
  ZenRecord build() => ref.read(storageServiceProvider).loadZen();

  /// The level the player is ON (1-based): one board = one level — the
  /// many-levels feel (owner decision). Every 10th level is a milestone
  /// finale with double pay + chest; modifiers roll out on the same cycle.
  int get level => state.boardsCleared + 1;

  /// Position inside the current 10-level milestone cycle (0-based).
  int get chapterPosition => state.boardsCleared % Difficulty.clearsPerLevel;

  /// DEBUG-ONLY playtest shortcut: jump the progression forward without
  /// playing (gated behind kDebugMode at the call site — never reachable in
  /// release builds).
  void debugAdvance(int boards) {
    final updated =
        state.copyWith(boardsCleared: state.boardsCleared + boards);
    state = updated;
    ref.read(storageServiceProvider).saveZen(updated);
  }

  /// Records a board clear and updates the flow chain. [clean] = no wrong
  /// traces and no hints. Returns the new total cleared.
  int recordClear({required bool clean}) {
    final chain = clean ? state.chain + 1 : 0;
    final updated = state.copyWith(
      boardsCleared: state.boardsCleared + 1,
      chain: chain,
      bestChain: chain > state.bestChain ? chain : state.bestChain,
    );
    state = updated;
    ref.read(storageServiceProvider).saveZen(updated);
    return updated.boardsCleared;
  }
}

final zenControllerProvider =
    NotifierProvider<ZenController, ZenRecord>(ZenController.new);
