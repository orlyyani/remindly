import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_item.dart';
import '../utils/date_math.dart';

/// Owns all local-notification scheduling.
///
/// Design rule (see CLAUDE.md §4): stored [ReminderItem]s are the source of
/// truth; scheduled notifications are derived state. [reconcile] rebuilds the
/// entire schedule from the items, and is called on every app launch and after
/// any change. Uses exact, zoned alarms so date-sensitive reminders fire on the
/// right day even in Doze.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription =
      'Upcoming vehicle and life maintenance reminders';

  /// Set by the app so a tapped notification can open the relevant item.
  /// Receives the item id carried in the notification payload.
  void Function(String itemId)? onSelectItem;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (e) {
      // Fall back to UTC if the platform zone can't be resolved; scheduling
      // still works, just anchored to UTC.
      debugPrint('Could not resolve local timezone, using UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onSelectItem?.call(payload);
        }
      },
    );

    await _androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Requests notification + exact-alarm permissions (Android 13+ / 12+).
  /// Safe to call every launch; the OS only prompts when needed.
  Future<void> requestPermissions() async {
    final android = _androidPlugin;
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
  }

  /// Returns the app id used if the app was launched by tapping a notification
  /// while it was terminated, so the app can navigate to it on startup.
  Future<String?> initialLaunchItemId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  /// The concrete local datetimes an active item should fire at, one per lead
  /// time, skipping any already in the past. Exposed (and pure w.r.t. `now`)
  /// so it can be unit-tested. [defaultHour]/[defaultMinute] apply when the
  /// item has no per-item time.
  List<tz.TZDateTime> scheduleTimesFor(
    ReminderItem item, {
    required int defaultHour,
    required int defaultMinute,
    required tz.TZDateTime now,
  }) {
    final hour = item.notificationHour ?? defaultHour;
    final minute = item.notificationMinute ?? defaultMinute;
    final due = item.nextDueDate;

    final times = <tz.TZDateTime>[];
    for (final lead in item.leadTimes) {
      final base = dateOnly(due).subtract(Duration(days: lead));
      final fire = tz.TZDateTime(
          tz.local, base.year, base.month, base.day, hour, minute);
      if (fire.isAfter(now)) times.add(fire);
    }
    return times;
  }

  Future<void> _scheduleOne(
      int id, ReminderItem item, tz.TZDateTime when) async {
    await _plugin.zonedSchedule(
      id: id,
      title: item.title,
      body:
          '${item.category.label} · due ${item.nextDueDate.day}/${item.nextDueDate.month}/${item.nextDueDate.year}',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: item.id,
    );
  }

  /// Cancels then reschedules all of one item's notifications.
  Future<void> scheduleForItem(
    ReminderItem item, {
    required int defaultHour,
    required int defaultMinute,
  }) async {
    await cancelForItem(item);
    if (!item.isActive || !_initialized) return;
    final now = tz.TZDateTime.now(tz.local);
    final times = scheduleTimesFor(item,
        defaultHour: defaultHour, defaultMinute: defaultMinute, now: now);
    for (var i = 0; i < times.length; i++) {
      await _scheduleOne(item.notificationBaseId + i, item, times[i]);
    }
  }

  /// Cancels every notification belonging to an item (across all its lead times).
  Future<void> cancelForItem(ReminderItem item) async {
    // Cancel a generous range of ids from the item's base to cover any lead
    // times that may have been removed since the last schedule.
    for (var i = 0; i < 32; i++) {
      await _plugin.cancel(id: item.notificationBaseId + i);
    }
  }

  /// Rebuilds the whole schedule from the given items. Source-of-truth sync.
  Future<void> reconcile(
    List<ReminderItem> items, {
    required int defaultHour,
    required int defaultMinute,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final item in items) {
      if (!item.isActive) continue;
      final times = scheduleTimesFor(item,
          defaultHour: defaultHour, defaultMinute: defaultMinute, now: now);
      for (var i = 0; i < times.length; i++) {
        await _scheduleOne(item.notificationBaseId + i, item, times[i]);
      }
    }
  }

  /// Fires a notification a few seconds out — used by Settings' "Test" button.
  Future<void> showTestNotification() async {
    if (!_initialized) return;
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _plugin.zonedSchedule(
      id: _testId,
      title: 'Test reminder',
      body: 'If you can see this, notifications are working. 🎉',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static const int _testId = 2147483646; // near max 32-bit int, avoids item ids
}
