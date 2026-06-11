import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../services/persisted_models.dart';
import 'providers.dart';

/// Tracks Zen progress: total boards cleared (drives the difficulty ramp and
/// the displayed chapter) and the flow chain (consecutive clean clears).
class ZenController extends Notifier<ZenRecord> {
  @override
  ZenRecord build() => ref.read(storageServiceProvider).loadZen();

  /// The chapter a player is currently on (1-based for display; one chapter =
  /// [Difficulty.clearsPerLevel] boards, matching the home card's progress bar).
  int get level => state.boardsCleared ~/ Difficulty.clearsPerLevel + 1;

  /// Boards cleared within the current chapter (0-based position).
  int get chapterPosition => state.boardsCleared % Difficulty.clearsPerLevel;

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
