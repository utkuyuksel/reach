import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/engine/difficulty.dart';
import 'package:reach/engine/models/grid.dart';
import 'package:reach/engine/models/puzzle.dart';
import 'package:reach/engine/models/tile.dart';
import 'package:reach/game/screens/game_screen.dart';
import 'package:reach/game/state/game_controller.dart';
import 'package:reach/game/state/game_session.dart';
import 'package:reach/game/state/providers.dart';
import 'package:reach/services/ad_service.dart';
import 'package:reach/services/analytics_service.dart';
import 'package:reach/services/persisted_models.dart';
import 'package:reach/services/prefs_storage_service.dart';
import 'package:reach/services/purchase_service.dart';
import 'package:reach/services/remote_config_service.dart';
import 'package:reach/services/sound_service.dart';

/// 2×2, target 4. Tiles keyed by id 0..3 so they're findable despite repeated
/// values. Partition: [0,1] = 1+3, [2,3] = 3+1.
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

Future<ProviderContainer> _pump(WidgetTester tester) async {
  final storage = InMemoryStorageService();
  await storage.init();
  // Skip the first-run tutorial overlay so it doesn't block the board.
  await storage.saveSettings(const Settings(onboardingDone: true));

  final container = ProviderContainer(overrides: [
    storageServiceProvider.overrideWithValue(storage),
    adServiceProvider.overrideWithValue(DevAdService()),
    purchaseServiceProvider.overrideWithValue(DevPurchaseService()),
    analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
    remoteConfigServiceProvider.overrideWithValue(LocalRemoteConfigService()),
    soundServiceProvider.overrideWithValue(NoopSoundService()),
  ]);
  container
      .read(gameControllerProvider.notifier)
      .startWithPuzzle(_puzzle(), GameMode.zen);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: GameScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _trace(WidgetTester tester, int fromId, int toId) async {
  final g = await tester.startGesture(
    tester.getCenter(find.byKey(ValueKey('t$fromId'))),
  );
  await tester.pump();
  await g.moveTo(tester.getCenter(find.byKey(ValueKey('t$toId'))));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tracing a group that sums to the target clears it', (tester) async {
    final container = await _pump(tester);
    await _trace(tester, 0, 1); // 1 + 3 = 4
    expect(container.read(gameControllerProvider)!.found, 1);
    expect(find.byKey(const ValueKey('t0')), findsNothing); // cleared
  });

  testWidgets('clearing every group wins the board', (tester) async {
    final container = await _pump(tester);
    await _trace(tester, 0, 1);
    await _trace(tester, 2, 3);
    expect(container.read(gameControllerProvider)!.isWon, isTrue);
    expect(find.text('Cleared.'), findsOneWidget);
  });

  testWidgets('undo restores a cleared group', (tester) async {
    final container = await _pump(tester);
    await _trace(tester, 0, 1);
    expect(container.read(gameControllerProvider)!.found, 1);

    await tester.tap(find.byIcon(Icons.undo_rounded));
    await tester.pumpAndSettle();

    expect(container.read(gameControllerProvider)!.found, 0);
    expect(find.byKey(const ValueKey('t0')), findsOneWidget); // back
    expect(find.byKey(const ValueKey('t1')), findsOneWidget);
  });
}
