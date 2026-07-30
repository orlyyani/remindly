import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_item.dart';
import '../widgets/reminder_glyph.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import 'detail_screen.dart';

/// An agenda-style calendar: a horizontal strip of days for the month with the
/// selected day highlighted, and a vertical timeline of what's due that day
/// (each reminder sits at its notification time). No external calendar package.
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
  late DateTime _selected;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _selected = dateOnly(DateTime.now());
  }

  void _select(DateTime date) => setState(() => _selected = dateOnly(date));

  void _changeMonth(int delta) {
    setState(() => _selected = dateOnly(addMonthsClamped(_selected, delta)));
  }

  int _minutesOf(ReminderItem item) {
    final h = item.notificationHour ?? widget.settings.defaultHour;
    final m = item.notificationMinute ?? widget.settings.defaultMinute;
    return h * 60 + m;
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

          final selectedItems = [...?dueByDay[_selected]]
            ..sort((a, b) => _minutesOf(a).compareTo(_minutesOf(b)));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(theme),
              const SizedBox(height: 16),
              _dayStrip(theme, dueByDay),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _isToday(_selected) ? 'Today' : formatMediumDate(_selected),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: selectedItems.isEmpty
                    ? _emptyDay(theme)
                    : _timeline(theme, selectedItems),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isToday(DateTime d) => d == dateOnly(DateTime.now());

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            formatShortDate(_selected),
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Today" jump — only when we're not already on today.
              if (!_isToday(_selected))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: AppColors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _select(DateTime.now()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text('Today',
                            style: TextStyle(
                                color: AppColors.purple,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ),
              // Month pill with prev/next chevrons.
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chevron(
                        IconsaxPlusLinear.arrow_left_2, () => _changeMonth(-1)),
                    Text(_monthNames[_selected.month - 1],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    _chevron(
                        IconsaxPlusLinear.arrow_right_2, () => _changeMonth(1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chevron(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppColors.purple),
        ),
      );

  Widget _dayStrip(ThemeData theme, Map<DateTime, List<ReminderItem>> dueByDay) {
    // Exactly 5 days with the selected day centred: [-2, -1, 0, +1, +2].
    final days = [
      for (var offset = -2; offset <= 2; offset++)
        dateOnly(_selected.add(Duration(days: offset)))
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final date in days)
            Expanded(child: _dayCell(theme, date, dueByDay.containsKey(date))),
        ],
      ),
    );
  }

  Widget _dayCell(ThemeData theme, DateTime date, bool has) {
    final selected = date == _selected;
    final isToday = date == dateOnly(DateTime.now());
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _select(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 88,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.purple
              : (isDark ? theme.colorScheme.surface : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: !selected && isToday
              ? Border.all(
                  color: AppColors.purple.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppColors.purple.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: selected ? 18 : 10,
              offset: Offset(0, selected ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${date.day}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                )),
            const SizedBox(height: 4),
            Text(_weekdayAbbr[date.weekday - 1],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )),
            const SizedBox(height: 6),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: has
                    ? (selected ? Colors.white : AppColors.orange)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyDay(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(IconsaxPlusLinear.calendar_tick,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text('Nothing scheduled',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            Text('This day is clear.',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }

  Widget _timeline(ThemeData theme, List<ReminderItem> dayItems) {
    final showNow = _isToday(_selected);
    final nowMinutes = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
    // Index of the first item at/after "now" — where the red line goes.
    var nowIndex = dayItems.length;
    if (showNow) {
      for (var i = 0; i < dayItems.length; i++) {
        if (_minutesOf(dayItems[i]) >= nowMinutes) {
          nowIndex = i;
          break;
        }
      }
    }

    final children = <Widget>[];
    for (var i = 0; i < dayItems.length; i++) {
      if (showNow && i == nowIndex) children.add(const _NowMarker());
      final item = dayItems[i];
      children.add(_TimelineRow(
        item: item,
        timeLabel: TimeOfDay(
                hour: item.notificationHour ?? widget.settings.defaultHour,
                minute: item.notificationMinute ?? widget.settings.defaultMinute)
            .format(context),
        isFirst: i == 0,
        isLast: i == dayItems.length - 1,
        today: DateTime.now(),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailScreen(
            repository: widget.repository,
            settings: widget.settings,
            item: item,
          ),
        )),
      ));
    }
    if (showNow && nowIndex == dayItems.length) {
      children.add(const _NowMarker());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: children,
    );
  }
}

/// One row of the day timeline: a time label, a connecting rail with a dot, and
/// a compact event card tinted with the item's colour (solid when overdue).
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.timeLabel,
    required this.isFirst,
    required this.isLast,
    required this.today,
    required this.onTap,
  });

  final ReminderItem item;
  final String timeLabel;
  final bool isFirst;
  final bool isLast;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.displayColor;
    final overdue = dateOnly(item.nextDueDate).isBefore(dateOnly(today));
    final railColor = theme.colorScheme.onSurface.withValues(alpha: 0.10);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time label
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                timeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Rail: continuous line with a colour dot at the card's centre.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                    width: 2,
                    height: 18,
                    color: isFirst ? Colors.transparent : railColor),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 2, color: isLast ? Colors.transparent : railColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Event card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: overdue
                    ? color
                    : Color.alphaBlend(color.withValues(alpha: 0.10),
                        theme.colorScheme.surface),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                elevation: overdue ? 6 : 0,
                shadowColor: color.withValues(alpha: 0.4),
                child: InkWell(
                  onTap: onTap,
                  child: Opacity(
                    opacity: item.isActive ? 1 : 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          ReminderGlyph(
                            outline: item.iconOutline,
                            bold: item.iconBold,
                            color: overdue ? Colors.white : color,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: overdue
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  overdue
                                      ? 'Overdue · $timeLabel'
                                      : '${item.category.label} · $timeLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: overdue
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The red "now" line across the timeline when viewing today.
class _NowMarker extends StatelessWidget {
  const _NowMarker();

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53935);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text('now',
                style: TextStyle(
                    color: red, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
          ),
          const Expanded(child: Divider(color: red, thickness: 1.5)),
        ],
      ),
    );
  }
}
