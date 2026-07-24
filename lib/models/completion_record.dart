import 'package:hive/hive.dart';

part 'completion_record.g.dart';

/// One entry in a reminder's completion history: when it was marked done, and
/// what its due date was at that moment (so we can show "on time" vs "N days
/// late"). Stored inside [ReminderItem.completions].
@HiveType(typeId: 1)
class CompletionRecord extends HiveObject {
  CompletionRecord({
    required this.completedDate,
    required this.dueDate,
  });

  @HiveField(0)
  DateTime completedDate;

  /// The item's due date at the time it was completed.
  @HiveField(1)
  DateTime dueDate;

  /// Positive = completed after it was due (late by N days); 0 or negative = on
  /// time / early.
  int get daysLate => completedDate.difference(dueDate).inDays;

  bool get wasOnTime => daysLate <= 0;
}
