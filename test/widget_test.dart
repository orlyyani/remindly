import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/models/recurrence_type.dart';
import 'package:reminder_app/models/reminder_category.dart';
import 'package:reminder_app/models/reminder_item.dart';
import 'package:reminder_app/widgets/reminder_tile.dart';

ReminderItem _item(DateTime due) => ReminderItem(
      id: 'test',
      title: 'Car PMS',
      categoryName: ReminderCategory.car.name,
      nextDueDate: due,
      recurrenceTypeIndex: RecurrenceType.everyNMonths.index,
      recurrenceInterval: 6,
      leadTimes: const [7],
      notificationBaseId: 1000,
    );

void main() {
  testWidgets('ReminderTile shows title, formatted date and relative label',
      (tester) async {
    final today = DateTime(2026, 7, 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderTile(
            item: _item(DateTime(2026, 7, 31)),
            today: today,
            onTap: () {},
            onMarkDone: () {},
          ),
        ),
      ),
    );

    expect(find.text('Car PMS'), findsOneWidget);
    expect(find.text('31 Jul 2026 · Every 6 months'), findsOneWidget);
    expect(find.text('in 7 days'), findsOneWidget);
  });

  testWidgets('ReminderTile mark-done button fires callback', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReminderTile(
            item: _item(DateTime(2026, 7, 24)),
            today: DateTime(2026, 7, 24),
            onTap: () {},
            onMarkDone: () => done = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.check_circle_outline));
    expect(done, isTrue);
  });
}
