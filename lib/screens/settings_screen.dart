import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/backup_service.dart';
import '../data/reminder_repository.dart';
import '../services/notification_service.dart';

/// Settings: your name (local, optional), default reminder time & lead time,
/// a test notification, and local backup/restore.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.settings,
    required this.backupService,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final BackupService backupService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _hour = widget.settings.defaultHour;
  late int _minute = widget.settings.defaultMinute;
  late int _leadDays = widget.settings.defaultLeadDays;

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: widget.settings.displayName);
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Shown in the greeting'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null) {
      setState(() => widget.settings.displayName = v);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
      widget.settings.defaultHour = _hour;
      widget.settings.defaultMinute = _minute;
      await widget.repository.reconcileAll();
    }
  }

  Future<void> _pickLeadDays() async {
    final controller = TextEditingController(text: _leadDays.toString());
    final v = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default lead time'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'days before'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, int.tryParse(controller.text.trim())),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v >= 0) {
      setState(() => _leadDays = v);
      widget.settings.defaultLeadDays = v;
    }
  }

  Future<void> _export() async {
    try {
      await widget.backupService.exportToShareSheet();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _import() async {
    try {
      final count = await widget.backupService.importFromFile();
      if (count == null) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count reminder(s).')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = TimeOfDay(hour: _hour, minute: _minute).format(context);
    final name = widget.settings.displayName;

    return SafeArea(
      bottom: false,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Settings',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Your name'),
            subtitle: Text(name.isEmpty ? 'Not set' : name),
            trailing:
                TextButton(onPressed: _editName, child: const Text('Change')),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Default reminder time'),
            subtitle: Text('Reminders fire at $timeLabel'),
            trailing:
                TextButton(onPressed: _pickTime, child: const Text('Change')),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('Default lead time'),
            subtitle: Text('New reminders default to $_leadDays day(s) before'),
            trailing: TextButton(
                onPressed: _pickLeadDays, child: const Text('Change')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Send a test notification'),
            subtitle: const Text('Fires in ~5 seconds'),
            onTap: () async {
              await NotificationService.instance.requestPermissions();
              await NotificationService.instance.showTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Test notification scheduled (~5s)')));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Back up to a file'),
            subtitle: const Text('Export all reminders (save or share)'),
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore from a file'),
            subtitle: const Text('Replaces current reminders'),
            onTap: _import,
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'All data stays on this device. No account, no internet needed. '
              'Backups are plain files you control.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
