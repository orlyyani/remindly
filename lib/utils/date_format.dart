import 'date_math.dart';

/// Human-friendly formatting for due dates. Kept Flutter-free and pure so the
/// "in X days" logic can be unit-tested directly.

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "24 Jul 2026".
String formatDueDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Short month + day, e.g. "Aug 2".
String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// Month + day + year, e.g. "Aug 2, 2026".
String formatMediumDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'}';

/// Adaptive "how far away" phrase from a non-negative day count. Keeps the
/// number small and glanceable by stepping up the unit:
/// 5 -> "5 days", 20 -> "3 weeks", 100 -> "3 months", 500 -> "1 year".
String untilPhrase(int days) {
  if (days < 14) return _plural(days, 'day');
  if (days < 8 * 7) return _plural((days / 7).round(), 'week');
  if (days < 365) return _plural((days / 30).round(), 'month');
  return _plural((days / 365).round(), 'year');
}

/// Glanceable relative label used on the home list.
/// Overdue -> "Overdue by 3 weeks", today -> "Due today", future -> "in 4 months".
String relativeDueLabel(DateTime due, {required DateTime today}) {
  final days = daysBetween(today, due);
  if (days < 0) return 'Overdue by ${untilPhrase(-days)}';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'in ${untilPhrase(days)}';
}
