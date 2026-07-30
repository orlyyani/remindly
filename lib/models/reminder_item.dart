import 'package:hive/hive.dart';

import 'package:flutter/material.dart';

import 'completion_record.dart';
import 'recurrence_type.dart';
import 'reminder_category.dart';
import 'reminder_icon.dart';

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
    this.googleEventId,
    this.iconKey,
    this.autoCompleteWhenDue = false,
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

  /// Id of the mirrored Google Calendar event, when calendar sync is on. Null
  /// until first synced; used to update/delete the same event later.
  @HiveField(16)
  String? googleEventId;

  /// Optional per-item icon, stored as a [ReminderIcons] key. When null (or the
  /// key is unknown), the item shows its [category] icon instead.
  @HiveField(17)
  String? iconKey;

  /// When true, once the due date passes the app auto-marks the item done and
  /// rolls it to the next occurrence — useful for dates that happen on their
  /// own (birthdays, anniversaries). Default OFF so actionable renewals keep
  /// nudging until you act. defaultValue keeps upgrades reading old data safely.
  @HiveField(18, defaultValue: false)
  bool autoCompleteWhenDue;

  ReminderCategory get category => ReminderCategory.fromName(categoryName);
  set category(ReminderCategory value) => categoryName = value.name;

  RecurrenceType get recurrenceType =>
      RecurrenceType.fromIndex(recurrenceTypeIndex);
  set recurrenceType(RecurrenceType value) =>
      recurrenceTypeIndex = value.index;

  /// The outline (linear) glyph to display: the per-item [iconKey] if set,
  /// otherwise the category's default.
  IconData get iconOutline =>
      ReminderIcons.outlineFor(iconKey) ?? category.iconOutline;

  /// The bold (filled) glyph, layered under [iconOutline] for the two-tone look.
  IconData get iconBold =>
      ReminderIcons.boldFor(iconKey) ?? category.iconBold;

  /// The colour used to tint the card and icon. Derived from the icon's
  /// [IconFamily] when a per-item icon is set, otherwise falls back to the
  /// category colour (so icon-less items keep their old look).
  Color get displayColor =>
      ReminderIcons.familyFor(iconKey)?.color ?? category.color;
}
