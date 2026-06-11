import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';
import 'package:reach/game/state/daily_controller.dart';
import 'package:reach/game/state/game_controller.dart';
import 'package:reach/game/state/game_session.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/game/state/wallet_controller.dart';
import 'package:reach/game/state/zen_controller.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';
import 'package:reach/services/sound_service.dart';
import 'package:reach/util/date_key.dart';

/// 2×2, target 4. Partition: [0,1] = 1+3, [2,3] = 3+1.
Puzzle _puzzle() {
  final grid = Grid(rows: 2, cols: 2, cells: [
    Tile(id: 0, value: 1),
    Tile(id: 1, value: 3),
    Tile(id: 2, value: 3),
    Tile(id: 3, value: 1),
  ]);
  return Puzzle(
    initialGrid: grid,
    target: 4,
    difficulty: Difficulty.easy,
    seed: 0,
    groups: const [
      [0, 1],
      [2, 3],
    ],
  );
}

Future<ProviderContainer> _container() async {
  final storage = InMemoryStorageService();
  await storage.init();
  return ProviderContainer(overrides: [
    storageServiceProvider.overrideWithValue(storage),
    adServiceProvider.overrideWithValue(DevAdService()),
    purchaseServiceProvider.overrideWithValue(DevPurchaseService()),
    analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
    remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService()),
    soundServiceProvider.overrideWithValue(NoopSoundService()),
  ]);
}

void main() {
  test('clearing all groups wins and records a Zen board', () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);

    ctrl.submitPath([0, 1]);
    expect(c.read(gameControllerProvider)!.found, 1);
    expect(c.read(gameControllerProvider)!.isWon, isFalse);

    ctrl.submitPath([2, 3]);
    expect(c.read(gameControllerProvider)!.isWon, isTrue);
    expect(c.read(zenControllerProvider).boardsCleared, 1);
  });

  test('a wrong trace is a no-op (no penalty, no progress)', () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);

    ctrl.submitPath([0, 3]); // diagonal — not a path
    expect(c.read(gameControllerProvider)!.found, 0);
    ctrl.submitPath([0, 1, 2]); // 1+3+3 = 7 ≠ 4
    expect(c.read(gameControllerProvider)!.found, 0);
  });

  test('undo then re-win records the Zen clear again', () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);

    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(c.read(zenControllerProvider).boardsCleared, 1);

    ctrl.undo(); // restores [2,3]; clears the win-recorded guard
    expect(c.read(gameControllerProvider)!.isWon, isFalse);

    ctrl.submitPath([2, 3]); // win again
    expect(c.read(gameControllerProvider)!.isWon, isTrue);
    expect(c.read(zenControllerProvider).boardsCleared, 2);
  });

  test('Daily completion is idempotent and updates the streak', () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);
    // The clock-integrity guard only credits TODAY's board.
    final today = dateKeyFor(DateTime.now());
    ctrl.startWithPuzzle(_puzzle(), GameMode.daily, dateKey: today);

    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(c.read(dailyControllerProvider).currentStreak, 1);
    expect(c.read(dailyControllerProvider).isCompleted(today), isTrue);

    // Replaying the same day must not bump the streak again.
    ctrl.restart();
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(c.read(dailyControllerProvider).currentStreak, 1);
  });

  test('archive completion fills the calendar but never the streak', () async {
    final c = await _container();
    final config = c.read(gameConfigProvider);
    final start = c.read(walletControllerProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.archive, dateKey: '2026-06-01');

    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    final daily = c.read(dailyControllerProvider);
    expect(daily.isCompleted('2026-06-01'), isTrue);
    expect(daily.resultFor('2026-06-01')!.backfilled, isTrue);
    expect(daily.currentStreak, 0);
    expect(c.read(walletControllerProvider), start + config.archiveClearCoins);
  });

  test('zen finale pays double and the chapter chest lands on board 10',
      () async {
    final c = await _container();
    final config = c.read(gameConfigProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    final zen = c.read(zenControllerProvider.notifier);

    // Play 9 boards to reach the chapter finale position.
    for (var i = 0; i < 9; i++) {
      ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
      ctrl.submitPath([0, 1]);
      ctrl.submitPath([2, 3]);
    }
    expect(c.read(zenControllerProvider).boardsCleared, 9);

    final before = c.read(walletControllerProvider);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen, isFinale: true);
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    // Finale double + chapter chest (and the clean-chain milestone if hit).
    final earned = c.read(gameControllerProvider)!.coinsEarned;
    expect(earned >= config.coinsPerClear * 2 + config.chapterBonus, isTrue);
    expect(c.read(walletControllerProvider), before + earned);
    expect(zen.level, 2); // chapter rolled over
  });

  test('flow chain grows on clean clears and resets on a wrong trace',
      () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);

    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(c.read(zenControllerProvider).chain, 1);

    // A wrong trace breaks the next board's cleanliness → chain resets.
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
    ctrl.submitPath([0, 1, 2]); // wrong sum
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(c.read(zenControllerProvider).chain, 0);
    expect(c.read(zenControllerProvider).bestChain, 1);
  });

  test('session coinsEarned is set on win for the win sheet', () async {
    final c = await _container();
    final config = c.read(gameConfigProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(
      c.read(gameControllerProvider)!.coinsEarned >= config.coinsPerClear,
      isTrue,
    );
  });

  test('revealHint marks a hint and increments hintsUsed', () async {
    final c = await _container();
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);

    final shown = ctrl.revealHint();
    expect(shown, isTrue);
    expect(c.read(gameControllerProvider)!.hintCells, isNotEmpty);
    expect(c.read(gameControllerProvider)!.hintsUsed, 1);
  });

  test('clearing a board awards coins on top of the starting balance',
      () async {
    final c = await _container();
    final start = c.read(walletControllerProvider); // starting coins
    final config = c.read(gameConfigProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);

    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]); // win
    expect(c.read(walletControllerProvider), start + config.coinsPerClear);
  });

  test('a clean clear (no wrong traces) earns 3 stars', () async {
    final c = await _container();
    final config = c.read(gameConfigProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
    ctrl.submitPath([0, 1]);
    ctrl.submitPath([2, 3]);
    expect(config.starsForWrong(c.read(gameControllerProvider)!.wrongTraces), 3);
  });

  test('running out of moves flags stuck; undo clears it', () async {
    final c = await _container();
    // 1×4 of 2s, target 4. Partition [0,1],[2,3]; clearing [1,2] strands it.
    final grid = Grid(rows: 1, cols: 4, cells: [
      Tile(id: 0, value: 2),
      Tile(id: 1, value: 2),
      Tile(id: 2, value: 2),
      Tile(id: 3, value: 2),
    ]);
    final line = Puzzle(
      initialGrid: grid,
      target: 4,
      difficulty: Difficulty.easy,
      seed: 0,
      groups: const [
        [0, 1],
        [2, 3],
      ],
    );
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(line, GameMode.zen);

    ctrl.submitPath([1, 2]); // clears, isolating cells 0 and 3 → no moves left
    expect(c.read(gameControllerProvider)!.found, 1);
    expect(c.read(gameControllerProvider)!.stuck, isTrue);

    ctrl.undo();
    expect(c.read(gameControllerProvider)!.stuck, isFalse);
  });

  test('a rejected trace counts as a wrong trace (lowers stars)', () async {
    final c = await _container();
    final config = c.read(gameConfigProvider);
    final ctrl = c.read(gameControllerProvider.notifier);
    ctrl.startWithPuzzle(_puzzle(), GameMode.zen);
    ctrl.submitPath([0, 1, 2]); // wrong sum (7 ≠ 4) — a wrong trace
    expect(c.read(gameControllerProvider)!.wrongTraces, 1);
    expect(config.starsForWrong(1), lessThan(3));
  });
}
