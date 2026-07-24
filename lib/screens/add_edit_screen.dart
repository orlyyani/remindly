import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/recurrence_type.dart';
import '../models/reminder_category.dart';
import '../models/reminder_icon.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import '../utils/date_format.dart';
import '../utils/date_math.dart';
import '../widgets/alarm_clock.dart';

enum _RepeatMode { monthly, yearly, oneTime }

/// Create/edit form styled after the Remindly mockups: Name it, Group, Repeats
/// (Every N months / Yearly date / One time), an adaptive schedule row, and
/// multi-select "Nudge me" lead times, with a live "next due / first nudge"
/// summary.
class AddEditScreen extends StatefulWidget {
  const AddEditScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.existing,
    this.prefillTitle,
    this.prefillCategory,
    this.prefillYearly = false,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final ReminderItem? existing;

  /// Optional starting values when creating from a quick-add suggestion.
  final String? prefillTitle;
  final ReminderCategory? prefillCategory;
  final bool prefillYearly;

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;

  late ReminderCategory _category;
  String? _iconKey;
  late _RepeatMode _mode;
  late int _intervalMonths;
  late DateTime _lastDone; // for monthly
  late DateTime _fixedDate; // for yearly / one-time
  late Set<int> _leadDays;
  late bool _escalate;

  static const _leadOptions = [7, 14, 30];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final today = dateOnly(DateTime.now());
    _title = TextEditingController(text: e?.title ?? widget.prefillTitle ?? '');
    _category =
        e?.category ?? widget.prefillCategory ?? ReminderCategory.car;
    _iconKey = e?.iconKey;

    if (e == null) {
      _mode = widget.prefillYearly ? _RepeatMode.yearly : _RepeatMode.monthly;
      _intervalMonths = 6;
      _lastDone = today;
      _fixedDate = today.add(const Duration(days: 30));
      _leadDays = {widget.settings.defaultLeadDays};
      _escalate = true;
    } else {
      switch (e.recurrenceType) {
        case RecurrenceType.none:
          _mode = _RepeatMode.oneTime;
          break;
        case RecurrenceType.everyNYears:
          _mode = _RepeatMode.yearly;
          break;
        default:
          _mode = _RepeatMode.monthly;
      }
      _intervalMonths =
          e.recurrenceType == RecurrenceType.everyNMonths ? e.recurrenceInterval : 6;
      _lastDone = e.lastCompletedDate ??
          addMonthsClamped(e.nextDueDate, -_intervalMonths);
      _fixedDate = e.nextDueDate;
      _leadDays = e.leadTimes.toSet();
      _escalate = e.escalateWhenOverdue;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime get _nextDue {
    switch (_mode) {
      case _RepeatMode.monthly:
        return nextOccurrenceAfter(
          _lastDone,
          RecurrenceType.everyNMonths,
          _intervalMonths,
          reference: DateTime.now(),
        );
      case _RepeatMode.yearly:
        final today = dateOnly(DateTime.now());
        var d = DateTime(today.year, _fixedDate.month, _fixedDate.day);
        if (!d.isAfter(today)) d = DateTime(today.year + 1, _fixedDate.month, _fixedDate.day);
        return d;
      case _RepeatMode.oneTime:
        return _fixedDate;
    }
  }

  DateTime get _firstNudge {
    final maxLead = _leadDays.isEmpty ? 0 : _leadDays.reduce((a, b) => a > b ? a : b);
    return dateOnly(_nextDue).subtract(Duration(days: maxLead));
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
  }

  Future<void> _editInterval() async {
    final controller = TextEditingController(text: _intervalMonths.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repeat every how many months?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'months'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text.trim())),
              child: const Text('Set')),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => _intervalMonths = v);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_leadDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick at least one nudge time.')));
      return;
    }

    final RecurrenceType type;
    final int interval;
    switch (_mode) {
      case _RepeatMode.monthly:
        type = RecurrenceType.everyNMonths;
        interval = _intervalMonths;
        break;
      case _RepeatMode.yearly:
        type = RecurrenceType.everyNYears;
        interval = 1;
        break;
      case _RepeatMode.oneTime:
        type = RecurrenceType.none;
        interval = 1;
        break;
    }

    final leads = _leadDays.toList()..sort();

    if (_isEditing) {
      final item = widget.existing!;
      item.title = _title.text.trim();
      item.category = _category;
      item.iconKey = _iconKey;
      item.nextDueDate = _nextDue;
      item.recurrenceType = type;
      item.recurrenceInterval = interval;
      item.leadTimes = leads;
      item.escalateWhenOverdue = _escalate;
      item.lastCompletedDate = _mode == _RepeatMode.monthly ? _lastDone : null;
      await widget.repository.save(item);
    } else {
      final item = widget.repository.create(
        title: _title.text.trim(),
        category: _category,
        iconKey: _iconKey,
        nextDueDate: _nextDue,
        recurrenceType: type,
        recurrenceInterval: interval,
        leadTimes: leads,
        escalateWhenOverdue: _escalate,
        lastCompletedDate: _mode == _RepeatMode.monthly ? _lastDone : null,
      );
      await widget.repository.save(item);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('“${widget.existing!.title}” will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repository.delete(widget.existing!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _Header(
                title: _isEditing ? 'Edit reminder' : 'New Reminder',
                onBack: () => Navigator.of(context).pop(),
                onDelete: _isEditing ? _delete : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    _label('Name it'),
                    TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'e.g. Oil change, LTO registration'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Give it a name'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    _label('Group'),
                    Wrap(
                      spacing: 10,
                      children: [
                        for (final c in ReminderCategory.values)
                          _ChoicePill(
                            label: c.label,
                            selected: _category == c,
                            selectedColor: theme.colorScheme.secondary,
                            onTap: () => setState(() => _category = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _label('Icon'),
                    _iconPickerRow(),
                    const SizedBox(height: 22),
                    _label('Repeats'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ChoicePill(
                          label: 'Every N months',
                          selected: _mode == _RepeatMode.monthly,
                          selectedColor: AppColors.purple,
                          onTap: () =>
                              setState(() => _mode = _RepeatMode.monthly),
                        ),
                        _ChoicePill(
                          label: 'Yearly date',
                          selected: _mode == _RepeatMode.yearly,
                          selectedColor: AppColors.purple,
                          onTap: () =>
                              setState(() => _mode = _RepeatMode.yearly),
                        ),
                        _ChoicePill(
                          label: 'One time',
                          selected: _mode == _RepeatMode.oneTime,
                          selectedColor: AppColors.purple,
                          onTap: () =>
                              setState(() => _mode = _RepeatMode.oneTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _scheduleRow(),
                    const SizedBox(height: 22),
                    _label('Nudge me'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final d in _leadOptions)
                          _ChoicePill(
                            label: _leadLabel(d),
                            selected: _leadDays.contains(d),
                            selectedColor: theme.colorScheme.secondary,
                            onTap: () => setState(() {
                              if (!_leadDays.remove(d)) _leadDays.add(d);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _escalate,
                      onChanged: (v) => setState(() => _escalate = v),
                      title: const Text('Keep nudging daily once overdue'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Then again as it gets closer — gently, then louder. '
                      'Next due ${formatShortDate(_nextDue)}, first nudge '
                      '${formatShortDate(_firstNudge)}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(_isEditing ? 'Save changes  →' : 'Set Reminder  →'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The icon shown right now: the chosen one, or the category default.
  IconData get _effectiveIcon =>
      ReminderIcons.resolve(_iconKey) ?? _category.icon;

  Widget _iconPickerRow() {
    final theme = Theme.of(context);
    final color = _category.color;
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _pickIcon,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_effectiveIcon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _iconKey == null ? 'Default for this group' : 'Custom icon',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_iconKey != null)
                TextButton(
                  onPressed: () => setState(() => _iconKey = null),
                  child: const Text('Reset'),
                ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickIcon() async {
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose an icon',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.count(
                    crossAxisCount: 5,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final ic in ReminderIcons.catalog)
                        _IconGridTile(
                          icon: ic.icon,
                          label: ic.label,
                          selected: ic.key == _iconKey,
                          color: _category.color,
                          onTap: () => Navigator.pop(context, ic.key),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) setState(() => _iconKey = selected);
  }

  Widget _scheduleRow() {
    switch (_mode) {
      case _RepeatMode.monthly:
        return Row(
          children: [
            Expanded(
              child: _PillField(
                label: 'every',
                value: '$_intervalMonths month${_intervalMonths == 1 ? '' : 's'}',
                onTap: _editInterval,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PillField(
                label: 'last done',
                value: formatShortDate(_lastDone),
                onTap: () async {
                  final d = await _pickDate(_lastDone);
                  if (d != null) setState(() => _lastDone = dateOnly(d));
                },
              ),
            ),
          ],
        );
      case _RepeatMode.yearly:
      case _RepeatMode.oneTime:
        return _PillField(
          label: _mode == _RepeatMode.yearly ? 'on this date each year' : 'on',
          value: _mode == _RepeatMode.yearly
              ? formatShortDate(_fixedDate)
              : formatDueDate(_fixedDate),
          onTap: () async {
            final d = await _pickDate(_fixedDate);
            if (d != null) setState(() => _fixedDate = dateOnly(d));
          },
        );
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );

  String _leadLabel(int d) {
    if (d == 7) return '1 week before';
    if (d == 14) return '2 weeks before';
    if (d == 30) return '1 month before';
    return '$d days before';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack, this.onDelete});
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: theme.colorScheme.surface,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                ),
              ),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (onDelete != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.surface,
                    child: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      onPressed: onDelete,
                    ),
                  ),
                )
              else
                const SizedBox(width: 56),
            ],
          ),
          const AlarmClock(size: 110),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? selectedColor
          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconGridTile extends StatelessWidget {
  const _IconGridTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.18)
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: selected
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
