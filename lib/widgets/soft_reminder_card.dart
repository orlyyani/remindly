import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../utils/date_format.dart';
import 'reminder_glyph.dart';
import '../utils/date_math.dart';

/// A soft pastel "Next up" card: title and one glanceable line (when it's due),
/// with the reminder's icon in a tinted circle. Tapping opens the detail screen,
/// where the full schedule / nudge plan lives.
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

  /// One short, glanceable line — just when it's due. Everything else (category,
  /// schedule, nudge plan) lives on the detail screen.
  String _subtitle() {
    final days = daysBetween(today, item.nextDueDate);
    if (days < 0) return 'Overdue by ${untilPhrase(-days)}';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'in ${untilPhrase(days)} · ${formatShortDate(item.nextDueDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.displayColor;
    // A much softer, near-surface tint so the card reads light and airy like
    // the reference, with the emoji carrying the colour.
    final tint = Color.alphaBlend(
        color.withValues(alpha: 0.07), theme.colorScheme.surface);

    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      shadowColor: color.withValues(alpha: 0.22),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: item.isActive ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _EmojiIllustration(item: item, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big rounded emoji illustration on the right of a card — a soft tinted
/// blob (in the item's family colour) with the emoji floating on it, echoing
/// the 3D-illustration look of the reference.
class _EmojiIllustration extends StatelessWidget {
  const _EmojiIllustration({required this.item, required this.color});

  final ReminderItem item;
  final Color color;
  static const double size = 68;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ReminderGlyph(
        outline: item.iconOutline,
        bold: item.iconBold,
        color: color,
        size: size * 0.46,
      ),
    );
  }
}
