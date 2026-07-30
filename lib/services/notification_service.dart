import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_item.dart';
import '../utils/date_math.dart';
import '../utils/friendly_copy.dart';

/// One planned notification: when it fires plus the (fixed-at-schedule-time)
/// text, and the stable id to use.
class _Nudge {
  _Nudge({required this.id, required this.when, required this.title, required this.body});
  final int id;
  final tz.TZDateTime when;
  final String title;
  final String body;
}

/// Owns all local-notification scheduling.
///
/// Stored [ReminderItem]s are the source of truth; notifications are derived
/// state. [reconcile] rebuilds the whole schedule. Supports multiple lead-time
/// nudges, escalating daily nudges once overdue, and snooze.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'reminders';
  static const String _channelName = 'Reminders';
  static const String _channelDescription =
      'Upcoming vehicle and life maintenance reminders';

  /// How many days of daily "still overdue" nudges to schedule.
  static const int _overdueDays = 14;

  /// Set by the app so a tapped notification can open the relevant item.
  void Function(String itemId)? onSelectItem;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (e) {
      debugPrint('Could not resolve local timezone, using UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Never let a notification-setup failure brick app startup — init() runs
    // before runApp(), so an unhandled throw here would freeze the splash.
    try {
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
    } catch (e) {
      debugPrint('Notification init failed (notifications off this run): $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> requestPermissions() async {
    final android = _androidPlugin;
    if (android == null) return;
    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
  }

  Future<String?> initialLaunchItemId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  /// Builds the concrete list of nudges an active item should fire, skipping
  /// anything already in the past. Pure w.r.t. [now] so it can be reasoned about.
  List<_Nudge> _plan(
    ReminderItem item, {
    required int defaultHour,
    required int defaultMinute,
    required tz.TZDateTime now,
  }) {
    final hour = item.notificationHour ?? defaultHour;
    final minute = item.notificationMinute ?? defaultMinute;
    final base = item.notificationBaseId;
    final nudges = <_Nudge>[];

    tz.TZDateTime at(DateTime day) =>
        tz.TZDateTime(tz.local, day.year, day.month, day.day, hour, minute);

    // Snoozed: a single nudge at the snooze time, nothing else.
    final snooze = item.snoozedUntil;
    if (snooze != null) {
      final when = tz.TZDateTime.from(snooze, tz.local);
      if (when.isAfter(now)) {
        final asToday = DateTime(snooze.year, snooze.month, snooze.day);
        nudges.add(_Nudge(
          id: base,
          when: when,
          title: FriendlyCopy.notificationTitle(item, today: asToday),
          body: FriendlyCopy.line(item, today: asToday),
        ));
      }
      return nudges;
    }

    final due = dateOnly(item.nextDueDate);

    // Lead-time nudges (e.g. 2 weeks / 3 days before).
    final leads = [...item.leadTimes]..sort();
    for (var i = 0; i < leads.length && i < 14; i++) {
      final fireDay = due.subtract(Duration(days: leads[i]));
      final when = at(fireDay);
      if (when.isAfter(now)) {
        nudges.add(_Nudge(
          id: base + 1 + i,
          when: when,
          title: FriendlyCopy.notificationTitle(item, today: fireDay),
          body: FriendlyCopy.line(item, today: fireDay),
        ));
      }
    }

    // Escalating daily nudges once overdue.
    if (item.escalateWhenOverdue) {
      for (var d = 0; d < _overdueDays; d++) {
        final fireDay = due.add(Duration(days: d));
        final when = at(fireDay);
        if (when.isAfter(now)) {
          nudges.add(_Nudge(
            id: base + 16 + d,
            when: when,
            title: FriendlyCopy.notificationTitle(item, today: fireDay),
            body: FriendlyCopy.line(item, today: fireDay),
          ));
        }
      }
    }

    return nudges;
  }

  Future<void> _scheduleOne(_Nudge n, String payload) async {
    await _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: n.when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Small icon defaults to the launcher icon (guaranteed present); the
          // colourful app icon also shows in the notification body.
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
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
    for (final n in _plan(item,
        defaultHour: defaultHour, defaultMinute: defaultMinute, now: now)) {
      await _scheduleOne(n, item.id);
    }
  }

  /// Cancels every notification belonging to an item (across all its ids).
  Future<void> cancelForItem(ReminderItem item) async {
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
      for (final n in _plan(item,
          defaultHour: defaultHour, defaultMinute: defaultMinute, now: now)) {
        await _scheduleOne(n, item.id);
      }
    }
  }

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
          // Small icon defaults to the launcher icon (guaranteed present); the
          // colourful app icon also shows in the notification body.
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static const int _testId = 2147483646;
}
