import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import '../utils/friendly_copy.dart';

/// A soft pastel "Next up" card: title, a category · schedule line with a warm
/// note, and a category icon in a circle. Tapping opens the detail screen.
class SoftReminderCard extends StatelessWidget {
  const SoftReminderCard({
    super.key,
    required this.item,
    required this.today,
    required this.onTap,
  });

  final ReminderItem item;
  final DateTime today;
  final VoidCallback onTap;

  String _subtitle() {
    final days = daysBetween(today, item.nextDueDate);
    final color = item.category;
    final schedule = item.recurrenceType.repeats
        ? item.recurrenceType.labelFor(item.recurrenceInterval)
        : 'One-time';

    // First nudge (largest lead) preview for future items.
    final maxLead = item.leadTimes.isEmpty
        ? 0
        : item.leadTimes.reduce((a, b) => a > b ? a : b);
    final firstNudge = dateOnly(item.nextDueDate).subtract(Duration(days: maxLead));

    if (days < 0) {
      return '${color.label} · was due ${formatShortDate(item.nextDueDate)}. ${FriendlyCopy.line(item, today: today)}';
    }
    if (item.recurrenceType.name == 'everyNYears') {
      return '$schedule · ${formatShortDate(item.nextDueDate)}. First nudge ${formatShortDate(firstNudge)}.';
    }
    if (days <= 14) {
      return '${color.label} · in $days days, ${formatShortDate(item.nextDueDate)}. ${FriendlyCopy.line(item, today: today)}';
    }
    return '${color.label} · $schedule · ${formatShortDate(item.nextDueDate)}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.category.color;
    final tint = AppColors.softTint(color, theme.colorScheme.surface);

    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: item.isActive ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.category.icon, color: color, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
