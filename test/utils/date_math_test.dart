import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/models/recurrence_type.dart';
import 'package:reminder_app/utils/date_math.dart';

void main() {
  group('addMonthsClamped', () {
    test('simple month advance keeps day', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), 6), DateTime(2026, 7, 15));
    });

    test('clamps to end of shorter month (Jan 31 + 1 = Feb 28)', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('leap year Feb 29 target', () {
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('rolls year over', () {
      expect(addMonthsClamped(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10));
    });

    test('12 months == 1 year, keeps month/day', () {
      expect(addMonthsClamped(DateTime(2026, 3, 5), 12), DateTime(2027, 3, 5));
    });

    test('Feb 29 + 12 months clamps to Feb 28 in non-leap year', () {
      expect(addMonthsClamped(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
    });

    test('negative months roll year back correctly', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });
  });

  group('advanceOnce', () {
    test('none returns unchanged', () {
      final d = DateTime(2026, 5, 1);
      expect(advanceOnce(d, RecurrenceType.none, 3), d);
    });

    test('everyNDays', () {
      expect(advanceOnce(DateTime(2026, 5, 1), RecurrenceType.everyNDays, 10),
          DateTime(2026, 5, 11));
    });

    test('everyNWeeks', () {
      expect(advanceOnce(DateTime(2026, 5, 1), RecurrenceType.everyNWeeks, 2),
          DateTime(2026, 5, 15));
    });

    test('everyNMonths clamps', () {
      expect(advanceOnce(DateTime(2026, 8, 31), RecurrenceType.everyNMonths, 6),
          DateTime(2027, 2, 28));
    });

    test('everyNYears keeps month/day', () {
      expect(advanceOnce(DateTime(2026, 6, 15), RecurrenceType.everyNYears, 1),
          DateTime(2027, 6, 15));
    });
  });

  group('nextOccurrenceAfter', () {
    test('advances a long-overdue monthly item past today in one result', () {
      final due = DateTime(2026, 1, 1);
      final today = DateTime(2026, 7, 24);
      final next = nextOccurrenceAfter(
        due,
        RecurrenceType.everyNMonths,
        6,
        reference: today,
      );
      // Jan 1 -> Jul 1 (still <= today) -> Jan 1 2027.
      expect(next, DateTime(2027, 1, 1));
      expect(dateOnly(next).isAfter(dateOnly(today)), isTrue);
    });

    test('due already in the future is returned unchanged', () {
      final due = DateTime(2026, 12, 1);
      final today = DateTime(2026, 7, 24);
      expect(
        nextOccurrenceAfter(due, RecurrenceType.everyNYears, 1,
            reference: today),
        due,
      );
    });

    test('non-repeating item returns due unchanged', () {
      final due = DateTime(2026, 1, 1);
      expect(
        nextOccurrenceAfter(due, RecurrenceType.none, 1,
            reference: DateTime(2026, 7, 24)),
        due,
      );
    });

    test('yearly birthday rolls to next year keeping month/day', () {
      final birthday = DateTime(2026, 3, 10);
      final today = DateTime(2026, 7, 24);
      expect(
        nextOccurrenceAfter(birthday, RecurrenceType.everyNYears, 1,
            reference: today),
        DateTime(2027, 3, 10),
      );
    });
  });

  group('daysBetween', () {
    test('positive for future, ignores time-of-day', () {
      expect(
        daysBetween(DateTime(2026, 7, 24, 23, 0), DateTime(2026, 7, 31, 1, 0)),
        7,
      );
    });

    test('negative for past', () {
      expect(daysBetween(DateTime(2026, 7, 24), DateTime(2026, 7, 20)), -4);
    });

    test('zero for same day', () {
      expect(daysBetween(DateTime(2026, 7, 24, 8), DateTime(2026, 7, 24, 20)), 0);
    });
  });
}
