import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_item.dart';
import '../utils/date_math.dart';
import '../widgets/featured_reminder_card.dart';
import '../widgets/soft_reminder_card.dart';
import 'detail_screen.dart';

/// The main tab: a warm greeting, a featured card for the most urgent
/// (overdue / due-today) item with quick actions, and soft "Next up" cards.
class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  final ReminderRepository repository;
  final AppSettings settings;

  void _openDetail(BuildContext context, ReminderItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(
        repository: repository,
        settings: settings,
        item: item,
      ),
    ));
  }

  Future<void> _snoozePrompt(BuildContext context, ReminderItem item) async {
    final days = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.snooze),
              title: const Text('Snooze 3 days'),
              onTap: () => Navigator.pop(context, 3),
            ),
            ListTile(
              leading: const Icon(Icons.snooze),
              title: const Text('Snooze 1 week'),
              onTap: () => Navigator.pop(context, 7),
            ),
          ],
        ),
      ),
    );
    if (days != null) await repository.snooze(item, days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = settings.displayName.trim();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                if (name.isNotEmpty)
                  Text('Hello, $name',
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55))),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Coming up '),
                    TextSpan(
                        text: 'for you',
                        style:
                            TextStyle(color: theme.colorScheme.secondary)),
                  ]),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: repository.box.listenable(),
              builder: (context, Box<ReminderItem> box, _) {
                final today = DateTime.now();
                final items = repository.allSortedByDue();
                if (items.isEmpty) return const _EmptyState();

                final first = items.first;
                final firstDays = daysBetween(today, first.nextDueDate);
                final hasFeatured = first.isActive && firstDays <= 0;
                final rest = hasFeatured ? items.sublist(1) : items;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (hasFeatured) ...[
                      _sectionLabel(context, 'Overdue'),
                      FeaturedReminderCard(
                        item: first,
                        today: today,
                        onTap: () => _openDetail(context, first),
                        onMarkDone: () => repository.markDone(first),
                        onSnooze: () => _snoozePrompt(context, first),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (rest.isNotEmpty)
                      _sectionLabel(context, hasFeatured ? 'Next up' : 'Coming up'),
                    for (final item in rest) ...[
                      SoftReminderCard(
                        item: item,
                        today: today,
                        onTap: () => _openDetail(context, item),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 72, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('Nothing scheduled yet',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap the + to add your first reminder —\nthen forget about it. We\'ll nudge you in time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
