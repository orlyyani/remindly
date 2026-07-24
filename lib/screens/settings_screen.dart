import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/reminder_repository.dart';
import '../services/notification_service.dart';

/// Small settings screen: default notification time, default lead time, and a
/// "test notification" button to confirm notifications work on this device.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  final ReminderRepository repository;
  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _hour = widget.settings.defaultHour;
  late int _minute = widget.settings.defaultMinute;
  late int _leadDays = widget.settings.defaultLeadDays;

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
      // Existing items using the default time need rescheduling.
      await widget.repository.reconcileAll();
    }
  }

  Future<void> _pickLeadDays() async {
    final controller = TextEditingController(text: _leadDays.toString());
    final value = await showDialog<int>(
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value >= 0) {
      setState(() => _leadDays = value);
      widget.settings.defaultLeadDays = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = TimeOfDay(hour: _hour, minute: _minute).format(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Default reminder time'),
            subtitle: Text('Reminders fire at $timeLabel'),
            trailing: TextButton(onPressed: _pickTime, child: const Text('Change')),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('Default lead time'),
            subtitle: Text(
                'New reminders default to $_leadDays day(s) before due'),
            trailing:
                TextButton(onPressed: _pickLeadDays, child: const Text('Change')),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Test notification scheduled (~5s)')),
                );
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'All data stays on this device. No account, no internet needed.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
