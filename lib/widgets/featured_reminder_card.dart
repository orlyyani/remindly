import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import 'reminder_glyph.dart';

/// The prominent purple card at the top of the list for the most urgent item
/// (overdue / due today): title, a plain-language status line, and quick
/// "Mark done" + "Snooze" actions.
class FeaturedReminderCard extends StatelessWidget {
  const FeaturedReminderCard({
    super.key,
    required this.item,
    required this.today,
    required this.onTap,
    required this.onMarkDone,
    required this.onSnooze,
    this.showSnooze = true,
  });

  final ReminderItem item;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onMarkDone;
  final VoidCallback onSnooze;
  final bool showSnooze;

  /// One clean line — when it's due. Category/schedule live on the detail screen.
  String _statusLine() {
    final days = daysBetween(today, item.nextDueDate);
    if (days < 0) {
      return 'Overdue by ${untilPhrase(-days)} · was due ${formatShortDate(item.nextDueDate)}';
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in ${untilPhrase(days)} · ${formatShortDate(item.nextDueDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.purple,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      elevation: 12,
      shadowColor: AppColors.purple.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusLine(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _IconBadge(item: item),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton(
                    onPressed: onMarkDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.purple,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      elevation: 0,
                    ),
                    child: const Text('Mark done'),
                  ),
                  if (showSnooze) ...[
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onSnooze,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        elevation: 0,
                      ),
                      child: const Text('Snooze'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.item});
  final ReminderItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ReminderGlyph(
        outline: item.iconOutline,
        bold: item.iconBold,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
