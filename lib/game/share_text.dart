import '../config/app_constants.dart';

/// Builds the **spoiler-free** Daily share string. It conveys that the board
/// was cleared, how many groups, whether it was clean (no hints), and the
/// streak — but never the target or which tiles to trace, so it can't spoil
/// the puzzle.
String buildDailyShareText({
  required String dateKey,
  required int groups,
  required int hintsUsed,
  required int currentStreak,
}) {
  final clean = hintsUsed == 0;

  // Neutral symbols: one ◆ per group (count only — no positions, no values).
  final capped = groups > 16 ? 16 : groups;
  final bar = '◆' * capped;

  final flair = clean ? '✦ clean' : '+$hintsUsed hint${hintsUsed == 1 ? '' : 's'}';
  final streakLine = currentStreak > 1 ? '\n🔥 $currentStreak-day streak' : '';

  return '$kAppName · Daily $dateKey\n'
      '$bar  ·  $flair$streakLine';
}
