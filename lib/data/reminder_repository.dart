// Repository keeps private box/settings/notification fields but exposes them via
// public constructor names, which trips prefer_initializing_formals — intended.
// ignore_for_file: prefer_initializing_formals
import 'package:hive/hive.dart';

import '../models/completion_record.dart';
import '../models/recurrence_type.dart';
import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import '../services/google_calendar_service.dart';
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
    GoogleCalendarService? calendar,
  })  : _box = box,
        _settings = settings,
        _notifications = notifications,
        _calendar = calendar;

  static const String boxName = 'reminders';

  final Box<ReminderItem> _box;
  final AppSettings _settings;
  final NotificationService _notifications;
  final GoogleCalendarService? _calendar;

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
    bool escalateWhenOverdue = true,
    DateTime? lastCompletedDate,
    String? iconKey,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return ReminderItem(
      id: id,
      title: title,
      categoryName: category.name,
      notes: notes,
      iconKey: iconKey,
      nextDueDate: dateOnly(nextDueDate),
      recurrenceTypeIndex: recurrenceType.index,
      recurrenceInterval: recurrenceInterval,
      leadTimes: leadTimes,
      notificationHour: notificationHour,
      notificationMinute: notificationMinute,
      isActive: isActive,
      escalateWhenOverdue: escalateWhenOverdue,
      lastCompletedDate: lastCompletedDate,
      notificationBaseId: _settings.allocateNotificationBaseId(),
    );
  }

  Future<void> save(ReminderItem item) async {
    await _box.put(item.id, item);
    await _reschedule(item);
    await _syncCalendar(item);
  }

  Future<void> delete(ReminderItem item) async {
    await _notifications.cancelForItem(item);
    final cal = _calendar;
    if (cal != null && cal.isConnected) await cal.delete(item);
    await _box.delete(item.id);
  }

  Future<void> setActive(ReminderItem item, bool active) async {
    item.isActive = active;
    await item.save();
    await _reschedule(item);
    await _syncCalendar(item);
  }

  /// Best-effort mirror to Google Calendar. No-op unless connected; never
  /// throws into callers (the local write already succeeded).
  Future<void> _syncCalendar(ReminderItem item) async {
    final cal = _calendar;
    if (cal == null || !cal.isConnected) return;
    if (item.isActive) {
      final id = await cal.push(item);
      if (id != item.googleEventId) {
        item.googleEventId = id;
        await item.save();
      }
    } else if (item.googleEventId != null) {
      await cal.delete(item);
      item.googleEventId = null;
      await item.save();
    }
  }

  /// Pushes every item's current state to the calendar (used after connecting).
  Future<void> syncAllToCalendar() async {
    final cal = _calendar;
    if (cal == null || !cal.isConnected) return;
    for (final item in _box.values.toList()) {
      await _syncCalendar(item);
    }
  }

  /// Marks an item done: records a completion in its history and rolls it to
  /// its next occurrence. One-time items are simply deactivated (no next date).
  ///
  /// [restartFromToday] (the default) advances from today; when false, the
  /// cycle is advanced from the original due date (keeps the fixed schedule,
  /// e.g. a birthday or a registration month).
  Future<void> markDone(
    ReminderItem item, {
    DateTime? now,
    bool restartFromToday = true,
  }) async {
    final today = dateOnly(now ?? DateTime.now());
    final completedDue = item.nextDueDate;

    item.completions.add(CompletionRecord(
      completedDate: today,
      dueDate: dateOnly(completedDue),
    ));
    item.lastCompletedDate = today;
    item.snoozedUntil = null;

    if (item.recurrenceType.repeats) {
      final anchor = restartFromToday ? today : completedDue;
      item.nextDueDate = nextOccurrenceAfter(
        anchor,
        item.recurrenceType,
        item.recurrenceInterval,
        reference: today,
      );
    } else {
      item.isActive = false;
    }
    await item.save();
    await _reschedule(item);
    await _syncCalendar(item);
  }

  /// Snoozes an item: suppress normal nudges and re-nudge [days] from now.
  Future<void> snooze(ReminderItem item, int days) async {
    final now = DateTime.now();
    item.snoozedUntil = DateTime(now.year, now.month, now.day + days,
        item.notificationHour ?? _settings.defaultHour,
        item.notificationMinute ?? _settings.defaultMinute);
    await item.save();
    await _reschedule(item);
  }

  Future<void> clearSnooze(ReminderItem item) async {
    item.snoozedUntil = null;
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
