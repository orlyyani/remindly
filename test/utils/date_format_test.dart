import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/utils/date_format.dart';

void main() {
  final today = DateTime(2026, 7, 24);

  group('relativeDueLabel', () {
    test('due today', () {
      expect(relativeDueLabel(DateTime(2026, 7, 24), today: today), 'Due today');
    });

    test('due tomorrow', () {
      expect(relativeDueLabel(DateTime(2026, 7, 25), today: today),
          'Due tomorrow');
    });

    test('future days', () {
      expect(relativeDueLabel(DateTime(2026, 7, 31), today: today), 'in 7 days');
    });

    test('overdue by 1 day (singular)', () {
      expect(relativeDueLabel(DateTime(2026, 7, 23), today: today),
          'Overdue by 1 day');
    });

    test('overdue by several days', () {
      expect(relativeDueLabel(DateTime(2026, 7, 20), today: today),
          'Overdue by 4 days');
    });

    test('future weeks', () {
      // 21 days out -> 3 weeks
      expect(relativeDueLabel(DateTime(2026, 8, 14), today: today), 'in 3 weeks');
    });

    test('future months', () {
      // 90 days out -> 3 months
      expect(relativeDueLabel(DateTime(2026, 10, 22), today: today), 'in 3 months');
    });

    test('future years', () {
      // ~1 year out
      expect(relativeDueLabel(DateTime(2027, 7, 24), today: today), 'in 1 year');
    });

    test('overdue steps up units too', () {
      expect(relativeDueLabel(DateTime(2026, 7, 3), today: today),
          'Overdue by 3 weeks');
    });
  });

  group('untilPhrase', () {
    test('days below two weeks', () {
      expect(untilPhrase(0), '0 days');
      expect(untilPhrase(1), '1 day');
      expect(untilPhrase(13), '13 days');
    });

    test('weeks between 2 and 8', () {
      expect(untilPhrase(14), '2 weeks');
      expect(untilPhrase(20), '3 weeks'); // rounds
    });

    test('months up to a year', () {
      expect(untilPhrase(56), '2 months'); // 8 weeks -> months
      expect(untilPhrase(100), '3 months');
    });

    test('years past a year', () {
      expect(untilPhrase(365), '1 year');
      expect(untilPhrase(740), '2 years');
    });
  });

  group('formatDueDate', () {
    test('formats day month year', () {
      expect(formatDueDate(DateTime(2026, 7, 24)), '24 Jul 2026');
    });
  });
}
