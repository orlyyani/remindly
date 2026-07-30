import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/completion_record.dart';
import '../models/reminder_item.dart';
import '../widgets/reminder_glyph.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import 'add_edit_screen.dart';

/// Full view of one reminder: status, mark-done (restart-from-today or keep the
/// original schedule), snooze, completion history, and the nudge plan.
class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.item,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final ReminderItem item;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ReminderItem get item => widget.item;

  Future<void> _markDone({required bool restartFromToday}) async {
    await widget.repository
        .markDone(item, restartFromToday: restartFromToday);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('“${item.title}” marked done')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _snooze(int days) async {
    await widget.repository.snooze(item, days);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Snoozed for $days day${days == 1 ? '' : 's'}')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _deleteCompletion(CompletionRecord record) async {
    await widget.repository.deleteCompletion(item, record);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this history?'),
        content: Text('Delete every completion log for “${item.title}”? '
            'The reminder and its schedule stay as they are.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.late),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await widget.repository.clearCompletions(item);
      if (mounted) setState(() {});
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditScreen(
        repository: widget.repository,
        settings: widget.settings,
        existing: item,
      ),
    ));
    if (mounted) setState(() {});
  }

  String _nudgePlan() {
    final leads = [...item.leadTimes]..sort((a, b) => b.compareTo(a));
    final parts = leads.map((d) {
      if (d == 0) return 'on the day';
      if (d % 7 == 0) {
        final w = d ~/ 7;
        return '$w week${w == 1 ? '' : 's'} before';
      }
      return '$d day${d == 1 ? '' : 's'} before';
    }).toList();
    if (item.escalateWhenOverdue) parts.add('then daily once overdue');
    return parts.isEmpty ? 'No nudges set.' : 'Nudges: ${parts.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final days = daysBetween(today, item.nextDueDate);
    final color = item.displayColor;
    final tint = AppColors.softTint(color, theme.colorScheme.surface);

    final nextFromToday = item.recurrenceType.repeats
        ? nextOccurrenceAfter(today, item.recurrenceType,
            item.recurrenceInterval,
            reference: today)
        : null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: tint,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: theme.colorScheme.surface,
                child: IconButton(
                  icon: const Icon(IconsaxPlusLinear.arrow_left_2),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _edit,
                child: Text('Edit',
                    style: TextStyle(
                        color: AppColors.purple, fontWeight: FontWeight.w700)),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.28),
                            color.withValues(alpha: 0.12),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: ReminderGlyph(
                        outline: item.iconOutline,
                        bold: item.iconBold,
                        color: color,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(item.title,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${item.category.label}'
                      '${item.recurrenceType.repeats ? ' · ${item.recurrenceType.labelFor(item.recurrenceInterval)}' : ' · one-time'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 12),
                    _StatusPill(days: days, due: item.nextDueDate),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _markDone(restartFromToday: true),
                      child: const Text('Mark done  →'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _SnoozeButton(
                              label: 'Snooze 3 days',
                              onPressed: () => _snooze(3))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _SnoozeButton(
                              label: 'Snooze 1 week',
                              onPressed: () => _snooze(7))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (nextFromToday != null) ...[
                    Text(
                      'Mark done restarts the cycle from today → next due '
                      '${formatShortDate(nextFromToday)}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          height: 1.4),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _markDone(restartFromToday: false),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: AppColors.purple),
                        child: const Text('Keep original schedule instead'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (item.completions.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('History',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _clearHistory,
                          icon: const Icon(IconsaxPlusLinear.trash, size: 18),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.late),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _HistoryCard(item: item, onDelete: _deleteCompletion),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    _nudgePlan(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.days, required this.due});
  final int days;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    Color bg;
    Color fg;
    if (days < 0) {
      final n = -days;
      text = 'Was due ${formatShortDate(due)} — $n day${n == 1 ? '' : 's'} overdue';
      bg = AppColors.overduePillBg;
      fg = AppColors.overduePillFg;
    } else if (days == 0) {
      text = 'Due today';
      bg = AppColors.overduePillBg;
      fg = AppColors.overduePillFg;
    } else {
      text = 'Due ${formatShortDate(due)} · in $days days';
      bg = theme.colorScheme.surface;
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      child: Text(text,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  const _SnoozeButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        minimumSize: const Size(0, 52),
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.onDelete});
  final ReminderItem item;
  final ValueChanged<CompletionRecord> onDelete;

  Future<bool> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this log?'),
        content: const Text(
            'Remove this entry from the history? This won\'t change the '
            'reminder itself.'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = item.completions.reversed.toList();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor),
            Dismissible(
              key: ObjectKey(entries[i]),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                color: AppColors.late.withValues(alpha: 0.15),
                child: const Icon(IconsaxPlusLinear.trash, color: AppColors.late),
              ),
              confirmDismiss: (_) => _confirm(context),
              onDismissed: (_) => onDelete(entries[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatMediumDate(entries[i].completedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      entries[i].wasOnTime
                          ? 'on time'
                          : '${entries[i].daysLate} days late',
                      style: TextStyle(
                        color: entries[i].wasOnTime
                            ? AppColors.onTime
                            : AppColors.late,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
