import 'date_math.dart';

/// Human-friendly formatting for due dates. Kept Flutter-free and pure so the
/// "in X days" logic can be unit-tested directly.

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "24 Jul 2026".
String formatDueDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Glanceable relative label used on the home list.
/// Overdue -> "Overdue by 3 days", today -> "Due today", future -> "in 5 days".
String relativeDueLabel(DateTime due, {required DateTime today}) {
  final days = daysBetween(today, due);
  if (days < 0) {
    final n = -days;
    return n == 1 ? 'Overdue by 1 day' : 'Overdue by $n days';
  }
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'in $days days';
}
