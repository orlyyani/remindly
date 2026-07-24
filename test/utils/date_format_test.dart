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
  });

  group('formatDueDate', () {
    test('formats day month year', () {
      expect(formatDueDate(DateTime(2026, 7, 24)), '24 Jul 2026');
    });
  });
}
