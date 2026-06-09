import '../config/app_constants.dart';

/// REACH's daily "epoch" — Daily #1. The share shows a Wordle-style puzzle
/// number counted from here, so each day reads as a collectible identity.
final DateTime _shareEpoch = DateTime.utc(2026, 1, 1);

/// Builds the **spoiler-free**, viral Daily result string.
///
/// It conveys *identity* (a daily puzzle number), *performance* (stars, and
/// clean vs hints), and a *streak* — plus a call-to-action link so it spreads.
/// It NEVER includes the target, tile values, or positions, so it cannot spoil
/// the puzzle for anyone who hasn't played yet. (The builder deliberately
/// accepts only abstract performance metrics — never the grid or target — so
/// a leak is impossible by construction.)
///
/// Example:
/// ```
/// REACH #160
/// 🟧🟧🟧🟧
/// ⭐⭐⭐  ·  ✨ clean  ·  🔥 5
///
/// https://reach.game
/// ```
String buildDailyShareText({
  required String dateKey,
  required int groups,
  required int stars,
  required int hintsUsed,
  required int currentStreak,
}) {
  final number = dailyNumber(dateKey);
  final header = number != null ? '$kAppName #$number' : '$kAppName · $dateKey';

  // Stars out of three — the performance brag.
  final s = stars.clamp(0, 3);
  final starRow = '⭐' * s + '☆' * (3 - s);

  // Brand-coloured signature: one tile per group cleared. A count only — the
  // same for everyone that day; never positions, values, or the target.
  final capped = groups > 12 ? 12 : (groups < 0 ? 0 : groups);
  final signature = '🟧' * capped;

  final flair = hintsUsed == 0
      ? '✨ clean'
      : '💡 $hintsUsed hint${hintsUsed == 1 ? '' : 's'}';
  final streak = currentStreak > 1 ? '  ·  🔥 $currentStreak' : '';

  // The CTA link is appended only when one is configured (see kShareUrl).
  final tail = kShareUrl.isEmpty ? '' : '\n\n$kShareUrl';

  return '$header\n'
      '$signature\n'
      '$starRow  ·  $flair$streak'
      '$tail';
}

/// Wordle-style puzzle number for [dateKey] (`YYYY-MM-DD`), or null if it can't
/// be parsed. Daily #1 is [_shareEpoch]. Computed in UTC so it never drifts
/// with the device timezone. Shared by the text share and the result card.
int? dailyNumber(String dateKey) {
  final parts = dateKey.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  final date = DateTime.utc(y, m, d);
  return date.difference(_shareEpoch).inDays + 1;
}
