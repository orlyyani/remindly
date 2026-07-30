import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

/// Broad colour families the icons are grouped into. The card colour is derived
/// from an icon's family (not the 3 categories), so colour tracks what the
/// reminder is *about* while staying glanceable — a handful of coherent hues
/// instead of 36 unrelated ones.
enum IconFamily {
  vehicles(Color(0xFF4C6FFF)), // blue
  renewals(Color(0xFFF5A623)), // amber (the app accent)
  money(Color(0xFF2E9E5B)), // green
  home(Color(0xFF12A4A4)), // teal
  health(Color(0xFFF2545B)), // coral
  personal(Color(0xFFE86AA6)); // pink

  const IconFamily(this.color);

  /// The card tint / icon colour for every icon in this family.
  final Color color;
}

/// A curated set of icons a reminder can use instead of its category default.
///
/// Icons come from the Iconsax set (matches the app's line/theme). Each entry
/// carries both the [outline] (linear) and [bold] (filled) glyph so cards can
/// render a two-tone "bulk" look: the filled shape faint underneath, the
/// outline crisp on top — see [ReminderGlyph].
///
/// Icons are stored on [ReminderItem] as a short String **key** (not a raw
/// code point) so the on-disk format stays stable. To add a choice: add one
/// entry to [catalog]. Old items referencing a key that later disappears fall
/// back to their category icon and colour.
class ReminderIcon {
  const ReminderIcon(this.key, this.label, this.family, this.outline, this.bold);

  final String key;
  final String label;

  /// The colour family this icon belongs to — drives the card colour.
  final IconFamily family;

  /// Linear (outline) and Bold (filled) glyphs from Iconsax, layered for a
  /// two-tone illustration.
  final IconData outline;
  final IconData bold;
}

class ReminderIcons {
  ReminderIcons._();

  /// The full picker list, roughly grouped: vehicles & maintenance first,
  /// then renewals/documents, money, home, health, then personal/dates.
  static const List<ReminderIcon> catalog = [
    // Vehicles & maintenance
    ReminderIcon('car', 'Car', IconFamily.vehicles, IconsaxPlusLinear.car, IconsaxPlusBold.car),
    ReminderIcon('motorcycle', 'Motorcycle', IconFamily.vehicles, IconsaxPlusLinear.speedometer, IconsaxPlusBold.speedometer),
    ReminderIcon('oil', 'Oil change', IconFamily.vehicles, IconsaxPlusLinear.drop, IconsaxPlusBold.drop),
    ReminderIcon('tire', 'Tires', IconFamily.vehicles, IconsaxPlusLinear.d_rotate, IconsaxPlusBold.d_rotate),
    ReminderIcon('fuel', 'Fuel', IconFamily.vehicles, IconsaxPlusLinear.gas_station, IconsaxPlusBold.gas_station),
    ReminderIcon('build', 'Service', IconFamily.vehicles, IconsaxPlusLinear.setting_2, IconsaxPlusBold.setting_2),
    ReminderIcon('battery', 'Battery', IconFamily.vehicles, IconsaxPlusLinear.battery_charging, IconsaxPlusBold.battery_charging),
    ReminderIcon('carwash', 'Car wash', IconFamily.vehicles, IconsaxPlusLinear.brush, IconsaxPlusBold.brush),

    // Renewals & documents
    ReminderIcon('doc', 'Document', IconFamily.renewals, IconsaxPlusLinear.document, IconsaxPlusBold.document),
    ReminderIcon('badge', 'License / ID', IconFamily.renewals, IconsaxPlusLinear.personalcard, IconsaxPlusBold.personalcard),
    ReminderIcon('shield', 'Insurance', IconFamily.renewals, IconsaxPlusLinear.shield, IconsaxPlusBold.shield),
    ReminderIcon('verified', 'Registration', IconFamily.renewals, IconsaxPlusLinear.verify, IconsaxPlusBold.verify),
    ReminderIcon('receipt', 'Renewal', IconFamily.renewals, IconsaxPlusLinear.receipt, IconsaxPlusBold.receipt),
    ReminderIcon('key', 'Subscription', IconFamily.renewals, IconsaxPlusLinear.key, IconsaxPlusBold.key),

    // Money
    ReminderIcon('money', 'Payment', IconFamily.money, IconsaxPlusLinear.money, IconsaxPlusBold.money),
    ReminderIcon('card', 'Card / bill', IconFamily.money, IconsaxPlusLinear.card, IconsaxPlusBold.card),
    ReminderIcon('savings', 'Savings', IconFamily.money, IconsaxPlusLinear.bank, IconsaxPlusBold.bank),

    // Home & utilities
    ReminderIcon('home', 'Home', IconFamily.home, IconsaxPlusLinear.home, IconsaxPlusBold.home),
    ReminderIcon('bolt', 'Electricity', IconFamily.home, IconsaxPlusLinear.flash, IconsaxPlusBold.flash),
    ReminderIcon('water', 'Water', IconFamily.home, IconsaxPlusLinear.drop, IconsaxPlusBold.drop),
    ReminderIcon('wifi', 'Internet', IconFamily.home, IconsaxPlusLinear.wifi, IconsaxPlusBold.wifi),
    ReminderIcon('cleaning', 'Cleaning', IconFamily.home, IconsaxPlusLinear.broom, IconsaxPlusBold.broom),
    ReminderIcon('plant', 'Plants', IconFamily.home, IconsaxPlusLinear.tree, IconsaxPlusBold.tree),

    // Health
    ReminderIcon('health', 'Health', IconFamily.health, IconsaxPlusLinear.activity, IconsaxPlusBold.activity),
    ReminderIcon('meds', 'Medication', IconFamily.health, IconsaxPlusLinear.health, IconsaxPlusBold.health),
    ReminderIcon('doctor', 'Doctor', IconFamily.health, IconsaxPlusLinear.hospital, IconsaxPlusBold.hospital),
    ReminderIcon('dentist', 'Dentist', IconFamily.health, IconsaxPlusLinear.emoji_happy, IconsaxPlusBold.emoji_happy),
    ReminderIcon('fitness', 'Fitness', IconFamily.health, IconsaxPlusLinear.weight, IconsaxPlusBold.weight),
    ReminderIcon('pet', 'Pet', IconFamily.health, IconsaxPlusLinear.pet, IconsaxPlusBold.pet),

    // Personal & dates
    ReminderIcon('birthday', 'Birthday', IconFamily.personal, IconsaxPlusLinear.cake, IconsaxPlusBold.cake),
    ReminderIcon('gift', 'Gift', IconFamily.personal, IconsaxPlusLinear.gift, IconsaxPlusBold.gift),
    ReminderIcon('anniversary', 'Anniversary', IconFamily.personal, IconsaxPlusLinear.lovely, IconsaxPlusBold.lovely),
    ReminderIcon('event', 'Event', IconFamily.personal, IconsaxPlusLinear.calendar, IconsaxPlusBold.calendar),
    ReminderIcon('flight', 'Travel', IconFamily.personal, IconsaxPlusLinear.airplane, IconsaxPlusBold.airplane),
    ReminderIcon('school', 'School', IconFamily.personal, IconsaxPlusLinear.teacher, IconsaxPlusBold.teacher),
    ReminderIcon('work', 'Work', IconFamily.personal, IconsaxPlusLinear.briefcase, IconsaxPlusBold.briefcase),
    ReminderIcon('star', 'General', IconFamily.personal, IconsaxPlusLinear.star, IconsaxPlusBold.star),
  ];

  static final Map<String, ReminderIcon> _byKey = {
    for (final e in catalog) e.key: e,
  };

  /// The outline (linear) glyph for a stored [key], or null if unset/unknown.
  static IconData? outlineFor(String? key) => key == null ? null : _byKey[key]?.outline;

  /// The bold (filled) glyph for a stored [key], or null if unset/unknown.
  static IconData? boldFor(String? key) => key == null ? null : _byKey[key]?.bold;

  /// The colour family for a stored [key], or null if unset/unknown (callers
  /// fall back to the category colour).
  static IconFamily? familyFor(String? key) => key == null ? null : _byKey[key]?.family;
}
