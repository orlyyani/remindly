import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/reminder_repository.dart';
import '../models/completion_record.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// The "Done" tab: everything you've completed, most recent first, with an
/// on-time / late tag — a quick sense of how you're keeping up.
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.repository});

  final ReminderRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Done',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: repository.box.listenable(),
              builder: (context, Box<ReminderItem> box, _) {
                final entries = <_Entry>[];
                for (final item in box.values) {
                  for (final c in item.completions) {
                    entries.add(_Entry(item, c));
                  }
                }
                entries.sort((a, b) =>
                    b.record.completedDate.compareTo(a.record.completedDate));

                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: theme.colorScheme.secondary),
                          const SizedBox(height: 12),
                          Text('Nothing marked done yet',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text('Completed reminders show up here.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  itemCount: entries.length,
                  separatorBuilder: (a, b) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: e.item.category.color
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(e.item.category.icon,
                                color: e.item.category.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.item.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text(
                                    formatMediumDate(e.record.completedDate),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6))),
                              ],
                            ),
                          ),
                          Text(
                            e.record.wasOnTime
                                ? 'on time'
                                : '${e.record.daysLate}d late',
                            style: TextStyle(
                                color: e.record.wasOnTime
                                    ? AppColors.onTime
                                    : AppColors.late,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  _Entry(this.item, this.record);
  final ReminderItem item;
  final CompletionRecord record;
}
