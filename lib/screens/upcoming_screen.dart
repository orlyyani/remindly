import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_math.dart';
import '../widgets/alarm_clock.dart';
import '../widgets/featured_reminder_card.dart';
import '../widgets/soft_reminder_card.dart';
import 'add_edit_screen.dart';
import 'detail_screen.dart';

/// The main tab: a warm greeting, a featured card for the soonest item (styled
/// as overdue when it is), soft "Next up" cards, and a friendly empty state
/// with quick-add suggestions.
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

  void _openAddPrefilled(
    BuildContext context, {
    required String title,
    required ReminderCategory category,
    required bool yearly,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditScreen(
        repository: repository,
        settings: settings,
        prefillTitle: title,
        prefillCategory: category,
        prefillYearly: yearly,
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

  String _featuredLabel(int days) {
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due today';
    return 'Up next';
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
                if (items.isEmpty) {
                  return _EmptyState(onSuggestion: (t, c, y) =>
                      _openAddPrefilled(context, title: t, category: c, yearly: y));
                }

                // Feature the soonest active item (overdue or not).
                final featured =
                    items.first.isActive ? items.first : null;
                final rest = featured == null ? items : items.sublist(1);
                final firstDays =
                    featured == null ? 0 : daysBetween(today, featured.nextDueDate);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (featured != null) ...[
                      _sectionLabel(context, _featuredLabel(firstDays)),
                      FeaturedReminderCard(
                        item: featured,
                        today: today,
                        showSnooze: firstDays <= 0,
                        onTap: () => _openDetail(context, featured),
                        onMarkDone: () => repository.markDone(featured),
                        onSnooze: () => _snoozePrompt(context, featured),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (rest.isNotEmpty) _sectionLabel(context, 'Next up'),
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

/// (title, category, yearly) for a quick-add suggestion.
typedef _SuggestionTap = void Function(
    String title, ReminderCategory category, bool yearly);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestion});

  final _SuggestionTap onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const AlarmClock(size: 150),
          ),
          const SizedBox(height: 28),
          Text('Nothing to keep track of. Yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 14),
          Text(
            'Add a reminder once — an oil change, a renewal, '
            'a birthday — and we\'ll nudge you before it\'s due.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _SuggestionChip(
                label: 'Oil change',
                onTap: () =>
                    onSuggestion('Oil change', ReminderCategory.car, false),
              ),
              _SuggestionChip(
                label: 'Registration',
                onTap: () =>
                    onSuggestion('Registration', ReminderCategory.car, true),
              ),
              _SuggestionChip(
                label: 'Insurance',
                onTap: () =>
                    onSuggestion('Insurance', ReminderCategory.car, true),
              ),
              _SuggestionChip(
                label: 'A birthday',
                onTap: () => onSuggestion(
                    'Birthday', ReminderCategory.personal, true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Text(label,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
