import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import 'date_format.dart';
import 'date_math.dart';

/// Warm, human microcopy for cards and notifications — the "gently, then louder"
/// voice from the design. Pure functions of an item + today, so they're easy to
/// reuse and test.
class FriendlyCopy {
  FriendlyCopy._();

  /// A short supportive line for the home card / notification body.
  static String line(ReminderItem item, {required DateTime today}) {
    final days = daysBetween(today, item.nextDueDate);
    final cat = item.category;

    if (days < 0) {
      final n = -days;
      switch (cat) {
        case ReminderCategory.motorcycle:
          return 'Your motorcycle misses you. Mark done or snooze.';
        case ReminderCategory.car:
          return 'Overdue by $n day${n == 1 ? '' : 's'} — a quick fix keeps it healthy.';
        case ReminderCategory.personal:
          return 'It slipped by — still worth marking done.';
      }
    }
    if (days == 0) return 'Due today. A good moment to take care of it.';
    if (days == 1) return 'Due tomorrow — you\'ve got this.';

    switch (cat) {
      case ReminderCategory.car:
        return days <= 10
            ? 'Good week to book the shop.'
            : 'On the horizon — no rush yet.';
      case ReminderCategory.motorcycle:
        return days <= 10
            ? 'Worth scheduling soon.'
            : 'Plenty of runway before it\'s due.';
      case ReminderCategory.personal:
        return days <= 35
            ? 'Plenty of time to plan something.'
            : 'Noted — we\'ll remind you closer.';
    }
  }

  /// Notification title, e.g. "Chain service is 4 days overdue" or
  /// "Oil change coming up — Aug 2".
  static String notificationTitle(ReminderItem item, {required DateTime today}) {
    final days = daysBetween(today, item.nextDueDate);
    if (days < 0) {
      final n = -days;
      return '${item.title} is $n day${n == 1 ? '' : 's'} overdue';
    }
    if (days == 0) return '${item.title} is due today';
    if (days == 1) return '${item.title} is due tomorrow';
    return '${item.title} coming up — ${formatShortDate(item.nextDueDate)}';
  }
}
