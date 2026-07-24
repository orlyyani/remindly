import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reminder_app/models/recurrence_type.dart';
import 'package:reminder_app/models/reminder_category.dart';
import 'package:reminder_app/models/reminder_item.dart';
import 'package:reminder_app/widgets/soft_reminder_card.dart';

ReminderItem _item(DateTime due) => ReminderItem(
      id: 'test',
      title: 'Oil change',
      categoryName: ReminderCategory.car.name,
      nextDueDate: due,
      recurrenceTypeIndex: RecurrenceType.everyNMonths.index,
      recurrenceInterval: 6,
      leadTimes: const [7],
      notificationBaseId: 1000,
    );

void main() {
  testWidgets('SoftReminderCard shows the title and fires onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoftReminderCard(
            item: _item(DateTime(2026, 8, 2)),
            today: DateTime(2026, 7, 24),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Oil change'), findsOneWidget);
    await tester.tap(find.byType(SoftReminderCard));
    expect(tapped, isTrue);
  });
}
