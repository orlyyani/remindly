import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/reminder_repository.dart';
import '../models/completion_record.dart';
import '../models/reminder_item.dart';
import '../widgets/reminder_glyph.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';

/// The "Done" tab: everything you've completed, most recent first, with an
/// on-time / late tag — a quick sense of how you're keeping up.
class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.repository});

  final ReminderRepository repository;

  Future<bool> _confirmDeleteOne(BuildContext context, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this log?'),
        content: Text('Remove this “$title” entry from your history? '
            'This won\'t change the reminder itself.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.late),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all logs?'),
        content: const Text(
            'This permanently deletes your entire completion history. '
            'Your reminders and their schedules stay exactly as they are.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.late),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (ok == true) await repository.clearAllCompletions();
  }

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
                          Icon(IconsaxPlusLinear.tick_circle,
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 12, 2),
                        child: TextButton.icon(
                          onPressed: () => _confirmClearAll(context),
                          icon: const Icon(IconsaxPlusLinear.trash, size: 20),
                          label: const Text('Clear all'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.late),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                        itemCount: entries.length,
                        separatorBuilder: (a, b) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return Dismissible(
                            key: ObjectKey(e.record),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: AppColors.late.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(IconsaxPlusLinear.trash,
                                  color: AppColors.late),
                            ),
                            confirmDismiss: (_) =>
                                _confirmDeleteOne(context, e.item.title),
                            onDismissed: (_) =>
                                repository.deleteCompletion(e.item, e.record),
                            child: _EntryTile(entry: e),
                          );
                        },
                      ),
                    ),
                  ],
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

/// A single completion-log row: emoji, title, completed date, and an on-time /
/// late tag. Wrapped in a [Dismissible] by the list for swipe-to-delete.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: e.item.displayColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ReminderGlyph(
              outline: e.item.iconOutline,
              bold: e.item.iconBold,
              color: e.item.displayColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.item.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text(formatMediumDate(e.record.completedDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6))),
              ],
            ),
          ),
          Text(
            e.record.wasOnTime ? 'on time' : '${e.record.daysLate}d late',
            style: TextStyle(
                color:
                    e.record.wasOnTime ? AppColors.onTime : AppColors.late,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
