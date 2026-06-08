import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/difficulty.dart';
import '../../services/persisted_models.dart';
import 'providers.dart';

/// Tracks Zen progress: total boards cleared, which drives both the difficulty
/// ramp and the displayed level.
class ZenController extends Notifier<ZenRecord> {
  @override
  ZenRecord build() => ref.read(storageServiceProvider).loadZen();

  /// The level a player is currently on (1-based for display).
  int get level => state.boardsCleared ~/ Difficulty.clearsPerLevel + 1;

  /// Records a board clear and returns the new total.
  int recordClear() {
    final updated =
        state.copyWith(boardsCleared: state.boardsCleared + 1);
    state = updated;
    ref.read(storageServiceProvider).saveZen(updated);
    return updated.boardsCleared;
  }
}

final zenControllerProvider =
    NotifierProvider<ZenController, ZenRecord>(ZenController.new);
