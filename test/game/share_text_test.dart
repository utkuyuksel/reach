import 'package:flutter_test/flutter_test.dart';
import 'package:reach/config/app_constants.dart';
import 'package:reach/game/share_text.dart';

/// The Daily share is a distribution surface: it must be braggable AND
/// spoiler-free. These guard both — the right signals are present, and nothing
/// that could spoil the puzzle (target/values/positions) can appear, because
/// the builder only ever receives abstract performance metrics.
void main() {
  String build({
    String dateKey = '2026-06-09',
    int groups = 4,
    int stars = 3,
    int hintsUsed = 0,
    int currentStreak = 5,
  }) =>
      buildDailyShareText(
        dateKey: dateKey,
        groups: groups,
        stars: stars,
        hintsUsed: hintsUsed,
        currentStreak: currentStreak,
      );

  group('daily share text', () {
    test('includes the app name and a daily puzzle number', () {
      final t = build();
      expect(t, contains(kAppName));
      // 2026-06-09 is 160 days from the 2026-01-01 epoch (#1).
      expect(t, contains('#160'));
    });

    test('puzzle number increments by one per day', () {
      int numberOf(String s) =>
          int.parse(RegExp(r'#(\d+)').firstMatch(s)!.group(1)!);
      expect(
        numberOf(build(dateKey: '2026-06-10')),
        numberOf(build(dateKey: '2026-06-09')) + 1,
      );
    });

    test('renders stars out of three', () {
      expect(build(stars: 3), contains('⭐⭐⭐'));
      expect(build(stars: 2), contains('⭐⭐☆'));
      expect(build(stars: 1), contains('⭐☆☆'));
    });

    test('shows a clean badge with no hints, a hint count otherwise', () {
      expect(build(hintsUsed: 0), contains('✨ clean'));
      expect(build(hintsUsed: 0), isNot(contains('💡')));
      expect(build(hintsUsed: 1), contains('1 hint'));
      final two = build(hintsUsed: 2);
      expect(two, contains('2 hints'));
      expect(two, isNot(contains('clean')));
    });

    test('shows the streak only when above one', () {
      expect(build(currentStreak: 5), contains('🔥 5'));
      expect(build(currentStreak: 1), isNot(contains('🔥')));
    });

    test('appends the CTA URL only when one is configured', () {
      final t = build();
      if (kShareUrl.isEmpty) {
        expect(t, isNot(contains('http')));
      } else {
        expect(t, endsWith(kShareUrl));
      }
    });

    test('the group signature is a count only (one tile per group)', () {
      expect(build(groups: 4), contains('🟧🟧🟧🟧'));
      expect(build(groups: 4), isNot(contains('🟧🟧🟧🟧🟧')));
    });

    test('falls back to the date if the key cannot be parsed', () {
      final t = build(dateKey: 'not-a-date');
      expect(t, contains('not-a-date'));
      expect(t, isNot(contains('#')));
    });
  });
}
