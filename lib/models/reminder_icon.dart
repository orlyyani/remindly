import 'package:flutter/material.dart';

/// A curated set of icons a reminder can use instead of its category default.
///
/// Icons are stored on [ReminderItem] as a short String **key** (not a raw
/// code point) so the on-disk format stays stable and Flutter's icon
/// tree-shaking keeps working — every [IconData] here is a const literal.
///
/// To add a choice: add one entry to [_catalog]. Old saved items referencing a
/// key that later disappears simply fall back to their category icon.
class ReminderIcon {
  const ReminderIcon(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

class ReminderIcons {
  ReminderIcons._();

  /// The full picker list, roughly grouped: vehicles & maintenance first,
  /// then renewals/documents, money, home, health, then personal/dates.
  static const List<ReminderIcon> catalog = [
    // Vehicles & maintenance
    ReminderIcon('car', 'Car', Icons.directions_car_filled),
    ReminderIcon('motorcycle', 'Motorcycle', Icons.two_wheeler),
    ReminderIcon('oil', 'Oil change', Icons.oil_barrel),
    ReminderIcon('tire', 'Tires', Icons.tire_repair),
    ReminderIcon('fuel', 'Fuel', Icons.local_gas_station),
    ReminderIcon('build', 'Service', Icons.build),
    ReminderIcon('battery', 'Battery', Icons.battery_charging_full),
    ReminderIcon('carwash', 'Car wash', Icons.local_car_wash),

    // Renewals & documents
    ReminderIcon('doc', 'Document', Icons.description),
    ReminderIcon('badge', 'License / ID', Icons.badge),
    ReminderIcon('shield', 'Insurance', Icons.shield),
    ReminderIcon('verified', 'Registration', Icons.verified),
    ReminderIcon('receipt', 'Renewal', Icons.receipt_long),
    ReminderIcon('key', 'Subscription', Icons.vpn_key),

    // Money
    ReminderIcon('money', 'Payment', Icons.payments),
    ReminderIcon('card', 'Card / bill', Icons.credit_card),
    ReminderIcon('savings', 'Savings', Icons.savings),

    // Home & utilities
    ReminderIcon('home', 'Home', Icons.home),
    ReminderIcon('bolt', 'Electricity', Icons.bolt),
    ReminderIcon('water', 'Water', Icons.water_drop),
    ReminderIcon('wifi', 'Internet', Icons.wifi),
    ReminderIcon('cleaning', 'Cleaning', Icons.cleaning_services),
    ReminderIcon('plant', 'Plants', Icons.local_florist),

    // Health
    ReminderIcon('health', 'Health', Icons.favorite),
    ReminderIcon('meds', 'Medication', Icons.medication),
    ReminderIcon('doctor', 'Doctor', Icons.medical_services),
    ReminderIcon('dentist', 'Dentist', Icons.emoji_emotions),
    ReminderIcon('fitness', 'Fitness', Icons.fitness_center),
    ReminderIcon('pet', 'Pet', Icons.pets),

    // Personal & dates
    ReminderIcon('birthday', 'Birthday', Icons.cake),
    ReminderIcon('gift', 'Gift', Icons.card_giftcard),
    ReminderIcon('anniversary', 'Anniversary', Icons.favorite_border),
    ReminderIcon('event', 'Event', Icons.event),
    ReminderIcon('flight', 'Travel', Icons.flight),
    ReminderIcon('school', 'School', Icons.school),
    ReminderIcon('work', 'Work', Icons.work),
    ReminderIcon('star', 'General', Icons.star),
  ];

  static final Map<String, IconData> _byKey = {
    for (final e in catalog) e.key: e.icon,
  };

  /// The icon for a stored [key], or null if the key is unset/unknown (callers
  /// fall back to the category icon).
  static IconData? resolve(String? key) => key == null ? null : _byKey[key];
}
