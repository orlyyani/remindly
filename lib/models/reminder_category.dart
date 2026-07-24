import 'package:flutter/material.dart';

/// The kind of thing a reminder is about. Drives grouping and color coding.
///
/// Ships with three categories (car, motorcycle, personal). Stored on
/// [ReminderItem] as the enum's [name] string so adding a category later
/// doesn't break existing saved data.
enum ReminderCategory {
  car,
  motorcycle,
  personal;

  /// Parse a stored category name back to the enum, defaulting to [personal]
  /// if the stored value is unknown (e.g. a category removed in a later build).
  static ReminderCategory fromName(String? name) {
    return ReminderCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ReminderCategory.personal,
    );
  }

  String get label {
    switch (this) {
      case ReminderCategory.car:
        return 'Car';
      case ReminderCategory.motorcycle:
        return 'Motorcycle';
      case ReminderCategory.personal:
        return 'Personal';
    }
  }

  /// Color used for the category dot/chip/card tint so the list scans at a glance.
  Color get color {
    switch (this) {
      case ReminderCategory.car:
        return const Color(0xFF4C6FFF); // indigo-blue
      case ReminderCategory.motorcycle:
        return const Color(0xFFF5A623); // orange
      case ReminderCategory.personal:
        return const Color(0xFFE86AA6); // pink
    }
  }

  IconData get icon {
    switch (this) {
      case ReminderCategory.car:
        return Icons.directions_car_filled;
      case ReminderCategory.motorcycle:
        return Icons.two_wheeler;
      case ReminderCategory.personal:
        return Icons.favorite;
    }
  }
}
