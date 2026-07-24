// Repository keeps private box/settings/notification fields but exposes them via
// public constructor names, which trips prefer_initializing_formals — intended.
// ignore_for_file: prefer_initializing_formals
import 'package:hive/hive.dart';

import '../models/recurrence_type.dart';
import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import '../services/notification_service.dart';
import '../utils/date_math.dart';
import 'app_settings.dart';

/// Single access point for reminder data (Hive) that keeps notifications in
/// sync. Every mutation reschedules notifications from the stored items so the
/// two never drift.
class ReminderRepository {
  ReminderRepository({
    required Box<ReminderItem> box,
    required AppSettings settings,
    required NotificationService notifications,
  })  : _box = box,
        _settings = settings,
        _notifications = notifications;

  static const String boxName = 'reminders';

  final Box<ReminderItem> _box;
  final AppSettings _settings;
  final NotificationService _notifications;

  Box<ReminderItem> get box => _box;

  /// All items sorted by soonest due date first (the home-list order).
  List<ReminderItem> allSortedByDue() {
    final items = _box.values.toList();
    items.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return items;
  }

  ReminderItem? byId(String id) => _box.get(id);

  /// Builds a new item, allocating id and notification range. Not yet saved.
  ReminderItem create({
    required String title,
    required ReminderCategory category,
    String? notes,
    required DateTime nextDueDate,
    required RecurrenceType recurrenceType,
    required int recurrenceInterval,
    required List<int> leadTimes,
    int? notificationHour,
    int? notificationMinute,
    bool isActive = true,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return ReminderItem(
      id: id,
      title: title,
      categoryName: category.name,
      notes: notes,
      nextDueDate: dateOnly(nextDueDate),
      recurrenceTypeIndex: recurrenceType.index,
      recurrenceInterval: recurrenceInterval,
      leadTimes: leadTimes,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      isActive: isActive,
      notificationBaseId: _settings.allocateNotificationBaseId(),
    );
  }

  Future<void> save(ReminderItem item) async {
    await _box.put(item.id, item);
    await _reschedule(item);
  }

  Future<void> delete(ReminderItem item) async {
    await _notifications.cancelForItem(item);
    await _box.delete(item.id);
  }

  Future<void> setActive(ReminderItem item, bool active) async {
    item.isActive = active;
    await item.save();
    await _reschedule(item);
  }

  /// Marks an item done: records completion and rolls it to its next
  /// occurrence. One-time items are simply deactivated (no next date).
  Future<void> markDone(ReminderItem item, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    item.lastCompletedDate = dateOnly(today);
    if (item.recurrenceType.repeats) {
      item.nextDueDate = nextOccurrenceAfter(
        item.nextDueDate,
        item.recurrenceType,
        item.recurrenceInterval,
        reference: today,
      );
    } else {
      item.isActive = false;
    }
    await item.save();
    await _reschedule(item);
  }

  /// Rebuilds the entire schedule from stored items. Call on app launch.
  Future<void> reconcileAll() async {
    await _notifications.reconcile(
      _box.values.toList(),
      defaultHour: _settings.defaultHour,
      defaultMinute: _settings.defaultMinute,
    );
  }

  Future<void> _reschedule(ReminderItem item) async {
    await _notifications.scheduleForItem(
      item,
      defaultHour: _settings.defaultHour,
      defaultMinute: _settings.defaultMinute,
    );
  }
}
