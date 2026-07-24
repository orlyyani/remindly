/// How a reminder repeats.
///
/// Stored on [ReminderItem] as the enum's [index] (an int). v1 ships months
/// and years (the anchor cases: PMS every 6 months, registration every year)
/// plus days/weeks for flexibility, and [none] for one-time events.
enum RecurrenceType {
  none,
  everyNDays,
  everyNWeeks,
  everyNMonths,
  everyNYears;

  /// Parse a stored index back to the enum, defaulting to [none] if out of range.
  static RecurrenceType fromIndex(int index) {
    if (index < 0 || index >= RecurrenceType.values.length) {
      return RecurrenceType.none;
    }
    return RecurrenceType.values[index];
  }

  bool get repeats => this != RecurrenceType.none;

  /// Human label for a given interval, e.g. (everyNMonths, 6) -> "Every 6 months".
  String labelFor(int interval) {
    switch (this) {
      case RecurrenceType.none:
        return 'One-time';
      case RecurrenceType.everyNDays:
        return interval == 1 ? 'Every day' : 'Every $interval days';
      case RecurrenceType.everyNWeeks:
        return interval == 1 ? 'Every week' : 'Every $interval weeks';
      case RecurrenceType.everyNMonths:
        return interval == 1 ? 'Every month' : 'Every $interval months';
      case RecurrenceType.everyNYears:
        return interval == 1 ? 'Every year' : 'Every $interval years';
    }
  }
}
