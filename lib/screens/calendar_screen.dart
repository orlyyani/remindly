import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import '../widgets/soft_reminder_card.dart';
import 'detail_screen.dart';

/// A lightweight month calendar: days with a due reminder get a dot; tapping a
/// day lists what's due then. No external calendar package — just a grid.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  final ReminderRepository repository;
  final AppSettings settings;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month; // first of the visible month
  DateTime? _selected;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = dateOnly(now);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder(
        valueListenable: widget.repository.box.listenable(),
        builder: (context, Box<ReminderItem> box, _) {
          final items = widget.repository.allSortedByDue();
          final dueByDay = <DateTime, List<ReminderItem>>{};
          for (final i in items) {
            final d = dateOnly(i.nextDueDate);
            dueByDay.putIfAbsent(d, () => []).add(i);
          }

          final selectedItems =
              _selected == null ? <ReminderItem>[] : (dueByDay[_selected] ?? []);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _monthHeader(theme),
              const SizedBox(height: 12),
              Row(
                children: _weekdays
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              _grid(theme, dueByDay),
              const SizedBox(height: 20),
              Text(
                _selected == null
                    ? ''
                    : 'Due on ${formatMediumDate(_selected!)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (selectedItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Nothing due this day.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                  ),
                )
              else
                for (final item in selectedItems) ...[
                  SoftReminderCard(
                    item: item,
                    today: DateTime.now(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DetailScreen(
                        repository: widget.repository,
                        settings: widget.settings,
                        item: item,
                      ),
                    )),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _monthHeader(ThemeData theme) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('${months[_month.month - 1]} ${_month.year}',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() =>
                  _month = DateTime(_month.year, _month.month - 1)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
                  _month = DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _grid(ThemeData theme, Map<DateTime, List<ReminderItem>> dueByDay) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Mon
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstWeekday - 1;
    final cells = <Widget>[];

    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    final today = dateOnly(DateTime.now());
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_month.year, _month.month, day);
      final has = dueByDay.containsKey(date);
      final isSelected = _selected == date;
      final isToday = date == today;
      cells.add(GestureDetector(
        onTap: () => setState(() => _selected = date),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.purple
                : (isToday
                    ? AppColors.purple.withValues(alpha: 0.12)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day',
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight:
                        isToday ? FontWeight.w800 : FontWeight.w500,
                  )),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: has
                      ? (isSelected ? Colors.white : AppColors.orange)
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: cells,
    );
  }
}
