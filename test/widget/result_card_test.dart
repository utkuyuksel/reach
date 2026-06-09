import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reach/config/app_constants.dart';
import 'package:reach/game/theme/palette.dart';
import 'package:reach/game/widgets/result_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int stars = 3,
    int hintsUsed = 0,
    int streak = 5,
    int groups = 4,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ResultCard(
              palette: GamePalette.clay,
              dayNumber: 160,
              dateKey: '2026-06-09',
              stars: stars,
              groups: groups,
              hintsUsed: hintsUsed,
              streak: streak,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the app name and daily number (+ CTA host when set)',
      (tester) async {
    await pump(tester);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('DAILY #160'), findsOneWidget);
    final host = Uri.parse(kShareUrl).host;
    if (host.isNotEmpty) {
      expect(find.text(host), findsOneWidget);
    }
  });

  testWidgets('shows three filled stars for a 3-star result', (tester) async {
    await pump(tester, stars: 3);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
  });

  testWidgets('a 2-star result fills two and outlines one', (tester) async {
    await pump(tester, stars: 2);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });

  testWidgets('clean badge + streak with no hints', (tester) async {
    await pump(tester, hintsUsed: 0, streak: 5);
    expect(find.text('clean'), findsOneWidget);
    expect(find.textContaining('day streak'), findsOneWidget);
  });

  testWidgets('hint count instead of clean, and streak hidden at 1',
      (tester) async {
    await pump(tester, hintsUsed: 2, streak: 1);
    expect(find.text('2 hints'), findsOneWidget);
    expect(find.text('clean'), findsNothing);
    expect(find.textContaining('day streak'), findsNothing);
  });
}
