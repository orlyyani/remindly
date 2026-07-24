import 'package:hive/hive.dart';

/// App-wide settings persisted in a small key/value Hive box of primitives.
/// v1 keeps this deliberately tiny: a default notification time and default
/// lead time. Also holds the monotonic counter used to allocate notification
/// id ranges for new items.
class AppSettings {
  AppSettings(this._box);

  final Box _box;

  static const String boxName = 'settings';

  static const _kHour = 'defaultHour';
  static const _kMinute = 'defaultMinute';
  static const _kLeadDays = 'defaultLeadDays';
  static const _kNextIdBase = 'nextIdBase';
  static const _kDisplayName = 'displayName';
  static const _kHasSeenWelcome = 'hasSeenWelcome';
  static const _kCalendarConnected = 'calendarConnected';

  /// Optional local name shown in the home greeting. Empty = no name (no account,
  /// stored only on this device).
  String get displayName => _box.get(_kDisplayName, defaultValue: '') as String;
  set displayName(String v) => _box.put(_kDisplayName, v);

  bool get hasSeenWelcome =>
      _box.get(_kHasSeenWelcome, defaultValue: false) as bool;
  set hasSeenWelcome(bool v) => _box.put(_kHasSeenWelcome, v);

  /// Whether the user opted into Google Calendar sync. Gates the silent
  /// session-restore on launch so we never prompt for Google before opt-in.
  bool get calendarConnected =>
      _box.get(_kCalendarConnected, defaultValue: false) as bool;
  set calendarConnected(bool v) => _box.put(_kCalendarConnected, v);

  int get defaultHour => _box.get(_kHour, defaultValue: 9) as int;
  set defaultHour(int v) => _box.put(_kHour, v);

  int get defaultMinute => _box.get(_kMinute, defaultValue: 0) as int;
  set defaultMinute(int v) => _box.put(_kMinute, v);

  int get defaultLeadDays => _box.get(_kLeadDays, defaultValue: 7) as int;
  set defaultLeadDays(int v) => _box.put(_kLeadDays, v);

  /// Allocates a fresh notification id range for a new item. Each item reserves
  /// 32 ids (one per possible lead time), so ranges never overlap.
  int allocateNotificationBaseId() {
    final current = _box.get(_kNextIdBase, defaultValue: 1000) as int;
    _box.put(_kNextIdBase, current + 32);
    return current;
  }
}
