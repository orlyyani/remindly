import 'package:hive/hive.dart';

import 'completion_record.dart';
import 'recurrence_type.dart';
import 'reminder_category.dart';

part 'reminder_item.g.dart';

/// The one central entity of the app: a named event that repeats on a schedule
/// and reminds you a set number of days before it's due.
///
/// Stored in Hive. Enum-typed concepts (category, recurrence) are persisted as
/// primitives ([categoryName] / [recurrenceTypeIndex]) so the on-disk format
/// stays stable if the enums grow later. The [category] / [recurrenceType]
/// getters convert back to the enums for use in the app.
@HiveType(typeId: 0)
class ReminderItem extends HiveObject {
  ReminderItem({
    required this.id,
    required this.title,
    required this.categoryName,
    this.notes,
    required this.nextDueDate,
    required this.recurrenceTypeIndex,
    required this.recurrenceInterval,
    required this.leadTimes,
    this.notificationHour,
    this.notificationMinute,
    this.isActive = true,
    this.lastCompletedDate,
    required this.notificationBaseId,
    List<CompletionRecord>? completions,
    this.snoozedUntil,
    this.escalateWhenOverdue = true,
  }) : completions = completions ?? <CompletionRecord>[];

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  /// Stored as [ReminderCategory.name]. Read via [category].
  @HiveField(2)
  String categoryName;

  @HiveField(3)
  String? notes;

  /// Date-level granularity (time-of-day is carried separately). The next date
  /// this item is due.
  @HiveField(4)
  DateTime nextDueDate;

  /// Stored as [RecurrenceType.index]. Read via [recurrenceType].
  @HiveField(5)
  int recurrenceTypeIndex;

  /// The N in "every N months/years/…". Ignored when recurrence is [none].
  @HiveField(6)
  int recurrenceInterval;

  /// "Remind me this many days before" values, e.g. [7] or [7, 1].
  @HiveField(7)
  List<int> leadTimes;

  /// Per-item notification time (optional). When null, the app-wide default
  /// from settings is used.
  @HiveField(8)
  int? notificationHour;

  @HiveField(9)
  int? notificationMinute;

  /// Paused items are kept but not scheduled.
  @HiveField(10)
  bool isActive;

  @HiveField(11)
  DateTime? lastCompletedDate;

  /// Base id for this item's local notifications. Each lead time gets
  /// [notificationBaseId] + leadTimeIndex so ids stay unique and stable.
  @HiveField(12)
  int notificationBaseId;

  /// Completion history, newest appended last. Drives the Detail history list.
  @HiveField(13)
  List<CompletionRecord> completions;

  /// When set (and in the future), the item is snoozed: normal nudges are
  /// suppressed and a single reminder fires at this time instead.
  @HiveField(14)
  DateTime? snoozedUntil;

  /// When true, once the item is overdue it nudges again daily (for a bounded
  /// number of days) until marked done. defaultValue keeps upgrades safe when
  /// reading items saved before this field existed.
  @HiveField(15, defaultValue: true)
  bool escalateWhenOverdue;

  ReminderCategory get category => ReminderCategory.fromName(categoryName);
  set category(ReminderCategory value) => categoryName = value.name;

  RecurrenceType get recurrenceType =>
      RecurrenceType.fromIndex(recurrenceTypeIndex);
  set recurrenceType(RecurrenceType value) =>
      recurrenceTypeIndex = value.index;
}
