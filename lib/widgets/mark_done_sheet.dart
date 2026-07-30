import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';

/// Asks how to roll a recurring reminder forward when marking it done.
///
/// Returns `true` to restart the cycle from today, `false` to keep the original
/// (fixed) schedule, or `null` if dismissed. "Keep original schedule" is the
/// default — listed first and highlighted — since fixed dates (birthdays,
/// renewals) are the common case. Callers should skip this for one-time items.
Future<bool?> showMarkDoneChooser(BuildContext context, ReminderItem item) {
  final today = dateOnly(DateTime.now());
  final keep = nextOccurrenceAfter(
      item.nextDueDate, item.recurrenceType, item.recurrenceInterval,
      reference: today);
  final fromToday = nextOccurrenceAfter(
      today, item.recurrenceType, item.recurrenceInterval,
      reference: today);

  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text('Mark “${item.title}” done',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _MarkDoneOption(
              primary: true,
              icon: IconsaxPlusLinear.repeat,
              title: 'Keep original schedule',
              subtitle: 'Next due ${formatShortDate(keep)}',
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 10),
            _MarkDoneOption(
              primary: false,
              icon: IconsaxPlusLinear.calendar_tick,
              title: 'Move next date to today',
              subtitle: 'Next due ${formatShortDate(fromToday)}',
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MarkDoneOption extends StatelessWidget {
  const _MarkDoneOption({
    required this.primary,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool primary;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = primary
        ? AppColors.purple.withValues(alpha: 0.12)
        : theme.colorScheme.onSurface.withValues(alpha: 0.04);
    final accent = primary ? AppColors.purple : theme.colorScheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: accent,
                                fontSize: 16)),
                        if (primary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Default',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
