import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';

/// One reminder rendered as a rounded card: a colored category pill, a due
/// badge tinted by urgency, the title + schedule, optional notes, and a
/// prominent full-width "Mark done" button. Tapping the card opens the editor.
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
    final color = item.category.color;
    final paused = !item.isActive;

    return Opacity(
      opacity: paused ? 0.6 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryPill(
                      label: item.category.label,
                      icon: item.category.icon,
                      color: color,
                    ),
                    const Spacer(),
                    if (paused)
                      _PausedBadge(theme: theme)
                    else
                      _DueBadge(due: item.nextDueDate, today: today),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDueDate(item.nextDueDate)}'
                  '${item.recurrenceType.repeats ? ' · ${item.recurrenceType.labelFor(item.recurrenceInterval)}' : ''}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.notes!.trim(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onMarkDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.due, required this.today});

  final DateTime due;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = daysBetween(today, due);

    Color bg;
    Color fg;
    if (days <= 0) {
      bg = theme.colorScheme.errorContainer;
      fg = theme.colorScheme.onErrorContainer;
    } else if (days <= 7) {
      bg = const Color(0xFFFFE0B2); // soft amber
      fg = const Color(0xFF8A5000);
    } else {
      bg = theme.colorScheme.surfaceContainerHighest;
      fg = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        relativeDueLabel(due, today: today),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('Paused',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
