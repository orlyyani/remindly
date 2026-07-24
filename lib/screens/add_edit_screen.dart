import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../models/recurrence_type.dart';
import '../models/reminder_category.dart';
import '../models/reminder_item.dart';
import '../utils/date_format.dart';

/// Single form to create or edit a reminder. Sensible defaults let a new item
/// be created in seconds (Car, every 6 months, remind 7 days before).
class AddEditScreen extends StatefulWidget {
  const AddEditScreen({
    super.key,
    required this.repository,
    required this.settings,
    this.existing,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final ReminderItem? existing;

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;

  late ReminderCategory _category;
  late DateTime _dueDate;
  late RecurrenceType _recurrenceType;
  late int _interval;
  late List<int> _leadTimes;
  late bool _isActive;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? ReminderCategory.car;
    _dueDate = e?.nextDueDate ?? DateTime.now().add(const Duration(days: 30));
    _recurrenceType = e?.recurrenceType ?? RecurrenceType.everyNMonths;
    _interval = e?.recurrenceInterval ?? 6;
    _leadTimes = List<int>.from(
        e?.leadTimes ?? [widget.settings.defaultLeadDays]);
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _addLeadTime() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remind how many days before?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'days before'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value != null && value >= 0 && !_leadTimes.contains(value)) {
      setState(() {
        _leadTimes.add(value);
        _leadTimes.sort();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_leadTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one reminder lead time.')),
      );
      return;
    }

    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

    if (_isEditing) {
      final item = widget.existing!;
      item.title = _title.text.trim();
      item.category = _category;
      item.notes = notes;
      item.nextDueDate = _dueDate;
      item.recurrenceType = _recurrenceType;
      item.recurrenceInterval = _interval;
      item.leadTimes = _leadTimes;
      item.isActive = _isActive;
      await widget.repository.save(item);
    } else {
      final item = widget.repository.create(
        title: _title.text.trim(),
        category: _category,
        notes: notes,
        nextDueDate: _dueDate,
        recurrenceType: _recurrenceType,
        recurrenceInterval: _interval,
        leadTimes: _leadTimes,
        isActive: _isActive,
      );
      await widget.repository.save(item);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('“${widget.existing!.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.repository.delete(widget.existing!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit reminder' : 'New reminder'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Car PMS, LTO Registration',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            _CategorySelector(
              value: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Next due date'),
              subtitle: Text(formatDueDate(_dueDate)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Change'),
              ),
            ),
            const Divider(),
            _RecurrenceSelector(
              type: _recurrenceType,
              interval: _interval,
              onTypeChanged: (t) => setState(() => _recurrenceType = t),
              onIntervalChanged: (n) => setState(() => _interval = n),
            ),
            const Divider(),
            _LeadTimesEditor(
              leadTimes: _leadTimes,
              onAdd: _addLeadTime,
              onRemove: (v) => setState(() => _leadTimes.remove(v)),
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Plate number, policy #, shop name…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Turn off to pause without deleting'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? 'Save changes' : 'Create reminder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.value, required this.onChanged});

  final ReminderCategory value;
  final ValueChanged<ReminderCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in ReminderCategory.values)
              ChoiceChip(
                avatar: Icon(c.icon, size: 18, color: c.color),
                label: Text(c.label),
                selected: value == c,
                onSelected: (_) => onChanged(c),
              ),
          ],
        ),
      ],
    );
  }
}

class _RecurrenceSelector extends StatelessWidget {
  const _RecurrenceSelector({
    required this.type,
    required this.interval,
    required this.onTypeChanged,
    required this.onIntervalChanged,
  });

  final RecurrenceType type;
  final int interval;
  final ValueChanged<RecurrenceType> onTypeChanged;
  final ValueChanged<int> onIntervalChanged;

  String _unitLabel(RecurrenceType t) {
    switch (t) {
      case RecurrenceType.everyNDays:
        return 'days';
      case RecurrenceType.everyNWeeks:
        return 'weeks';
      case RecurrenceType.everyNMonths:
        return 'months';
      case RecurrenceType.everyNYears:
        return 'years';
      case RecurrenceType.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Repeats', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceType>(
          initialValue: type,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(
                value: RecurrenceType.none, child: Text('One-time')),
            DropdownMenuItem(
                value: RecurrenceType.everyNDays, child: Text('Every N days')),
            DropdownMenuItem(
                value: RecurrenceType.everyNWeeks,
                child: Text('Every N weeks')),
            DropdownMenuItem(
                value: RecurrenceType.everyNMonths,
                child: Text('Every N months')),
            DropdownMenuItem(
                value: RecurrenceType.everyNYears,
                child: Text('Every N years')),
          ],
          onChanged: (t) => onTypeChanged(t ?? RecurrenceType.none),
        ),
        if (type.repeats) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Every'),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: TextFormField(
                  initialValue: interval.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) onIntervalChanged(n);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(_unitLabel(type)),
            ],
          ),
        ],
      ],
    );
  }
}

class _LeadTimesEditor extends StatelessWidget {
  const _LeadTimesEditor({
    required this.leadTimes,
    required this.onAdd,
    required this.onRemove,
  });

  final List<int> leadTimes;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  String _label(int days) {
    if (days == 0) return 'On the day';
    if (days == 1) return '1 day before';
    return '$days days before';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Remind me', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final d in leadTimes)
              InputChip(
                label: Text(_label(d)),
                onDeleted: () => onRemove(d),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}
