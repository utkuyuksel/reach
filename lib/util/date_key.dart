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
