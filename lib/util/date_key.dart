/// Local-date helpers for the Daily Challenge. The Daily rolls over at local
/// midnight, so all keys use the device's local date.
library;

/// A stable 'YYYY-MM-DD' key for [date]'s local day.
String dateKeyFor(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parse a 'YYYY-MM-DD' key back to a local [DateTime] at midnight.
DateTime dateFromKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Whether [a] is exactly the calendar day before [b].
bool isDayBefore(DateTime a, DateTime b) {
  final next = DateTime(a.year, a.month, a.day).add(const Duration(days: 1));
  return next.year == b.year && next.month == b.month && next.day == b.day;
}

/// Whole calendar days from [a] to [b] (positive when [b] is later). Uses UTC
/// midnights so DST shifts can't produce off-by-one results.
int daysBetween(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ub.difference(ua).inDays;
}

/// A stable 'YYYY-MM' key for [date]'s local month.
String monthKeyFor(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

/// Number of days in the month of 'YYYY-MM' [monthKey].
int daysInMonth(String monthKey) {
  final parts = monthKey.split('-');
  final y = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  return DateTime(y, m + 1, 0).day;
}

/// The Monday of [date]'s week, as a 'YYYY-MM-DD' key — the weekly-event
/// identifier (and, via `dailySeed`, its deterministic art seed).
String weekKeyFor(DateTime date) {
  final monday = DateTime(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1));
  return dateKeyFor(monday);
}
