import '../models/recurrence_type.dart';

/// Pure date/recurrence math — the core logic of the app. No Flutter imports,
/// so it is straightforward to unit-test. See test/utils/date_math_test.dart.

/// Strips the time component, returning midnight of the same calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Last calendar day (28–31) of the given year/month.
int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Adds [months] to [d], clamping the day to the target month's last day.
///
/// e.g. Jan 31 + 1 month -> Feb 28 (or 29 in a leap year); Aug 31 + 6 months
/// -> Feb 28. Keeps the same day-of-month otherwise. Time is preserved.
DateTime addMonthsClamped(DateTime d, int months) {
  final zeroBased = d.month - 1 + months;
  // Floor division so negative month offsets roll the year back correctly.
  final year = d.year + (zeroBased / 12).floor();
  // Dart's % returns 0..11 for a positive divisor, so this is the 1..12 month.
  final month = zeroBased % 12 + 1;
  final lastDay = lastDayOfMonth(year, month);
  final day = d.day < lastDay ? d.day : lastDay;
  return DateTime(year, month, day, d.hour, d.minute);
}

/// Advances a due date by exactly one recurrence interval.
///
/// For yearly items this keeps the same month/day (Feb 29 clamps to Feb 28 in
/// non-leap years). Returns [due] unchanged for [RecurrenceType.none].
DateTime advanceOnce(DateTime due, RecurrenceType type, int interval) {
  final n = interval < 1 ? 1 : interval;
  switch (type) {
    case RecurrenceType.none:
      return due;
    case RecurrenceType.everyNDays:
      return DateTime(due.year, due.month, due.day + n, due.hour, due.minute);
    case RecurrenceType.everyNWeeks:
      return DateTime(
          due.year, due.month, due.day + n * 7, due.hour, due.minute);
    case RecurrenceType.everyNMonths:
      return addMonthsClamped(due, n);
    case RecurrenceType.everyNYears:
      return addMonthsClamped(due, n * 12);
  }
}

/// The next occurrence strictly after [reference] (default: today), advancing by
/// the recurrence interval as many times as needed.
///
/// Used when marking an item done or when a due date has slipped into the past:
/// we roll forward until the due date is in the future. Non-repeating items
/// return their due date unchanged (the caller deactivates them instead).
DateTime nextOccurrenceAfter(
  DateTime due,
  RecurrenceType type,
  int interval, {
  required DateTime reference,
}) {
  if (!type.repeats) return due;
  final ref = dateOnly(reference);
  var next = due;
  // Guard against pathological loops; a day/week/month/year interval will
  // always exceed any realistic gap well within this bound.
  var guard = 0;
  while (!dateOnly(next).isAfter(ref) && guard < 10000) {
    next = advanceOnce(next, type, interval);
    guard++;
  }
  return next;
}

/// Whole-day difference between two dates (date-only). Positive = [target] is
/// in the future relative to [from].
int daysBetween(DateTime from, DateTime target) {
  return dateOnly(target).difference(dateOnly(from)).inDays;
}
