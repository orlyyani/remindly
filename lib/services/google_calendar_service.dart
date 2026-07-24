import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/recurrence_type.dart';
import '../models/reminder_item.dart';
import '../utils/date_math.dart';

/// Optional, opt-in mirror of reminders to the user's Google Calendar.
///
/// Offline-first: the local store stays the source of truth and the app remains
/// the notifier. Calendar events carry NO reminders (useDefault=false, empty
/// overrides) so Google doesn't double-nudge. Every call is best-effort — if
/// the user isn't connected or the network fails, callers ignore the result.
class GoogleCalendarService {
  GoogleCalendarService._();
  static final GoogleCalendarService instance = GoogleCalendarService._();

  /// Web OAuth client ID from the Google Cloud console. Required on Android for
  /// [GoogleSignIn.authenticate]. Leave empty until you've set up OAuth; sync
  /// simply stays unavailable until then.
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const List<String> _scopes = <String>[gcal.CalendarApi.calendarEventsScope];
  static const String _calendarId = 'primary';

  final GoogleSignIn _gsi = GoogleSignIn.instance;
  GoogleSignInAccount? _account;
  bool _initialized = false;

  bool get isConnected => _account != null;
  String? get accountEmail => _account?.email;

  /// True once the OAuth client id is configured; otherwise the feature can't
  /// be used and the UI should say so.
  bool get isConfigured => serverClientId.isNotEmpty;

  Future<void> init() async {
    if (_initialized || !isConfigured) return;
    try {
      await _gsi.initialize(serverClientId: serverClientId);
      _initialized = true;
      // Try to restore a previous session silently.
      _account = await _gsi.attemptLightweightAuthentication();
    } catch (e) {
      debugPrint('Google sign-in init failed: $e');
    }
  }

  /// Interactive connect. Returns true on success. Throws are surfaced to the
  /// caller so Settings can show a message.
  Future<bool> connect() async {
    if (!isConfigured) return false;
    await init();
    if (!_gsi.supportsAuthenticate()) return false;
    final account = await _gsi.authenticate(scopeHint: _scopes);
    // Ensure the Calendar scope is actually granted.
    await account.authorizationClient.authorizeScopes(_scopes);
    _account = account;
    return true;
  }

  Future<void> disconnect() async {
    try {
      await _gsi.disconnect();
    } catch (_) {}
    _account = null;
  }

  Future<gcal.CalendarApi?> _api() async {
    final account = _account;
    if (account == null) return null;
    final authz =
        await account.authorizationClient.authorizationForScopes(_scopes);
    if (authz == null) return null;
    return gcal.CalendarApi(authz.authClient(scopes: _scopes));
  }

  String? _rrule(ReminderItem item) {
    final n = item.recurrenceInterval < 1 ? 1 : item.recurrenceInterval;
    switch (item.recurrenceType) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.everyNDays:
        return 'RRULE:FREQ=DAILY;INTERVAL=$n';
      case RecurrenceType.everyNWeeks:
        return 'RRULE:FREQ=WEEKLY;INTERVAL=$n';
      case RecurrenceType.everyNMonths:
        return 'RRULE:FREQ=MONTHLY;INTERVAL=$n';
      case RecurrenceType.everyNYears:
        return 'RRULE:FREQ=YEARLY;INTERVAL=$n';
    }
  }

  gcal.Event _event(ReminderItem item) {
    final due = dateOnly(item.nextDueDate);
    final desc = <String>[
      item.category.label,
      if (item.notes != null && item.notes!.trim().isNotEmpty) item.notes!.trim(),
      'Synced from Remindly',
    ].join('\n');

    return gcal.Event(
      summary: item.title,
      description: desc,
      start: gcal.EventDateTime(date: DateTime(due.year, due.month, due.day)),
      end: gcal.EventDateTime(
          date: DateTime(due.year, due.month, due.day + 1)),
      recurrence: [if (_rrule(item) != null) _rrule(item)!],
      // App is the notifier — no calendar popups.
      reminders: gcal.EventReminders(useDefault: false, overrides: []),
    );
  }

  /// Creates or updates the mirrored event. Returns the event id to store on
  /// the item (or the existing id / null on failure).
  Future<String?> push(ReminderItem item) async {
    try {
      final api = await _api();
      if (api == null) return item.googleEventId;
      final event = _event(item);
      final existingId = item.googleEventId;
      if (existingId != null) {
        try {
          final updated =
              await api.events.update(event, _calendarId, existingId);
          return updated.id ?? existingId;
        } catch (_) {
          // Event was deleted on the calendar side — recreate.
          final created = await api.events.insert(event, _calendarId);
          return created.id;
        }
      }
      final created = await api.events.insert(event, _calendarId);
      return created.id;
    } catch (e) {
      debugPrint('Calendar push failed: $e');
      return item.googleEventId;
    }
  }

  Future<void> delete(ReminderItem item) async {
    final id = item.googleEventId;
    if (id == null) return;
    try {
      final api = await _api();
      if (api == null) return;
      await api.events.delete(_calendarId, id);
    } catch (e) {
      debugPrint('Calendar delete failed: $e');
    }
  }
}
