import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';

/// One row on the home list: category color/icon, title, due date, a glanceable
/// relative label, and a quick "done" action.
class ReminderTile extends StatelessWidget {
  const ReminderTile({
    super.key,
    required this.item,
    required this.today,
    required this.onTap,
    required this.onMarkDone,
  });

  final ReminderItem item;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daysBetween(today, item.nextDueDate);
    final color = item.category.color;

    // Tint the relative label by urgency: overdue/today red, within a week amber.
    Color labelColor = theme.colorScheme.onSurfaceVariant;
    if (days < 0) {
      labelColor = theme.colorScheme.error;
    } else if (days == 0) {
      labelColor = theme.colorScheme.error;
    } else if (days <= 7) {
      labelColor = Colors.orange.shade800;
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: Icon(item.category.icon),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatDueDate(item.nextDueDate)),
          Text(
            relativeDueLabel(item.nextDueDate, today: today),
            style: theme.textTheme.labelLarge?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!item.isActive)
            Text(
              'Paused',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'Mark done',
        icon: const Icon(Icons.check_circle_outline),
        onPressed: onMarkDone,
      ),
    );
  }
}
