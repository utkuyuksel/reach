import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_constants.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'state/game_controller.dart';
import 'state/providers.dart';
import 'theme/app_text.dart';

/// Dev affordance: boot straight into a game for screenshots / manual testing
/// without tapping through the home screen. Off by default. Enable with
/// `flutter run --dart-define=REACH_AUTOSTART=daily` (or `=zen`).
const String _autoStart = String.fromEnvironment('REACH_AUTOSTART');

/// Root widget. The theme follows the active palette so cosmetic theme changes
/// apply app-wide instantly.
class ReachApp extends ConsumerWidget {
  const ReachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: palette.paper,
        fontFamily: AppText.monoFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: Brightness.light,
        ).copyWith(surface: palette.paper),
      ),
      home: _autoStart.isEmpty ? const HomeScreen() : const _AutoStartGame(),
    );
  }
}

/// Starts a game immediately and shows the [GameScreen] (dev-only entry point).
class _AutoStartGame extends ConsumerStatefulWidget {
  const _AutoStartGame();

  @override
  ConsumerState<_AutoStartGame> createState() => _AutoStartGameState();
}

class _AutoStartGameState extends ConsumerState<_AutoStartGame> {
  @override
  void initState() {
    super.initState();
    // Defer: providers can't be modified during the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(gameControllerProvider.notifier);
      if (_autoStart == 'zen') {
        controller.startZen();
      } else {
        controller.startDaily();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const GameScreen();
}
