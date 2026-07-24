import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import '../widgets/reminder_tile.dart';
import 'add_edit_screen.dart';
import 'settings_screen.dart';

/// The main screen: upcoming reminders sorted soonest-first, filter chips by
/// category, mark-done, and a prominent add button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  final ReminderRepository repository;
  final AppSettings settings;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  ReminderCategory? _filter; // null = All

  /// Opens the add/edit form for [item] (or a new item when null). Public so a
  /// tapped notification can route straight here.
  Future<void> openEditor(ReminderItem? item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditScreen(
          repository: widget.repository,
          settings: widget.settings,
          existing: item,
        ),
      ),
    );
  }

  Future<void> _markDone(ReminderItem item) async {
    await widget.repository.markDone(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“${item.title}” marked done')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    repository: widget.repository,
                    settings: widget.settings,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryFilterBar(
            selected: _filter,
            onChanged: (c) => setState(() => _filter = c),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: widget.repository.box.listenable(),
              builder: (context, Box<ReminderItem> box, child) {
                var items = widget.repository.allSortedByDue();
                if (_filter != null) {
                  items =
                      items.where((i) => i.category == _filter).toList();
                }
                if (items.isEmpty) {
                  return _EmptyState(hasFilter: _filter != null);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ReminderTile(
                      item: item,
                      today: today,
                      onTap: () => openEditor(item),
                      onMarkDone: () => _markDone(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  final ReminderCategory? selected;
  final ValueChanged<ReminderCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          for (final c in ReminderCategory.values) ...[
            ChoiceChip(
              avatar: Icon(c.icon, size: 18, color: c.color),
              label: Text(c.label),
              selected: selected == c,
              onSelected: (_) => onChanged(c),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

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
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'Nothing in this category' : 'No reminders yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try a different category or add one.'
                  : 'Tap “Add” to create your first reminder —\nthen forget about it. We’ll nudge you in time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
