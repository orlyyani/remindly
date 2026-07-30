import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../data/app_settings.dart';
import '../data/backup_service.dart';
import '../data/reminder_repository.dart';
import '../services/google_calendar_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/reminder_glyph.dart';

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

  final _calendar = GoogleCalendarService.instance;
  bool _syncing = false;

  Future<void> _connectCalendar() async {
    setState(() => _syncing = true);
    try {
      final ok = await _calendar.connect();
      if (ok) {
        widget.settings.calendarConnected = true;
        await widget.repository.syncAllToCalendar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Connected to ${_calendar.accountEmail}. Synced.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Couldn\'t connect: $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnectCalendar() async {
    await _calendar.disconnect();
    widget.settings.calendarConnected = false;
    if (mounted) setState(() {});
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    await widget.repository.syncAllToCalendar();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Synced to Google Calendar')));
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

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Test notification scheduled (~5s)')));
    }
  }

  /// Short status line shown under the Google Calendar tile.
  String _calendarStatus() {
    if (!_calendar.isConfigured) return 'Not on this build';
    if (_calendar.isConnected) return _calendar.accountEmail ?? 'Connected';
    return 'Tap to connect';
  }

  /// The calendar actions live in a bottom sheet opened from its tile, so the
  /// grid stays simple while keeping connect / sync / disconnect available.
  Future<void> _openCalendarSheet() async {
    if (!_calendar.isConfigured) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Google Calendar sync'),
          content: const Text(
              'This build wasn\'t compiled with Google sign-in, so calendar '
              'sync is unavailable. Everything else works offline as usual.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    if (!_calendar.isConnected) {
      await _connectCalendar();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(IconsaxPlusLinear.calendar_tick, color: Color(0xFF2E9E5B)),
              title: const Text('Connected'),
              subtitle: Text(_calendar.accountEmail ?? ''),
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.refresh),
              title: const Text('Sync all now'),
              subtitle: const Text('Push every reminder to your calendar'),
              onTap: () {
                Navigator.pop(context);
                _syncNow();
              },
            ),
            ListTile(
              leading: const Icon(IconsaxPlusLinear.link_21),
              title: const Text('Disconnect'),
              subtitle: const Text('Stops syncing (existing events stay)'),
              onTap: () {
                Navigator.pop(context);
                _disconnectCalendar();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Remindly'),
        content: const Text(
          'Your reminders live on this device and work fully offline — no '
          'account needed. Backups are plain files you control. Google '
          'Calendar sync is optional; turn it on only if you want it.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = TimeOfDay(hour: _hour, minute: _minute).format(context);
    final name = widget.settings.displayName;

    final tiles = <Widget>[
      _SettingsTile(
        outline: IconsaxPlusLinear.user,
        bold: IconsaxPlusBold.user,
        label: 'Your name',
        subtitle: name.isEmpty ? 'Not set' : name,
        color: AppColors.purple,
        onTap: _editName,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.clock,
        bold: IconsaxPlusBold.clock,
        label: 'Reminder time',
        subtitle: timeLabel,
        color: AppColors.orange,
        onTap: _pickTime,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.calendar,
        bold: IconsaxPlusBold.calendar,
        label: 'Lead time',
        subtitle: '$_leadDays day${_leadDays == 1 ? '' : 's'} before',
        color: const Color(0xFF12A4A4),
        onTap: _pickLeadDays,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.notification,
        bold: IconsaxPlusBold.notification,
        label: 'Test alert',
        subtitle: 'Fires in ~5s',
        color: const Color(0xFF4C6FFF),
        onTap: _syncing ? null : _sendTestNotification,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.calendar_tick,
        bold: IconsaxPlusBold.calendar_tick,
        label: 'Google Calendar',
        subtitle: _calendarStatus(),
        color: const Color(0xFF2E9E5B),
        busy: _syncing,
        onTap: _syncing ? null : _openCalendarSheet,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.export_1,
        bold: IconsaxPlusBold.export_1,
        label: 'Back up',
        subtitle: 'Export to a file',
        color: const Color(0xFFE86AA6),
        onTap: _export,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.import_1,
        bold: IconsaxPlusBold.import_1,
        label: 'Restore',
        subtitle: 'Replaces current',
        color: const Color(0xFFF2545B),
        onTap: _import,
      ),
      _SettingsTile(
        outline: IconsaxPlusLinear.info_circle,
        bold: IconsaxPlusBold.info_circle,
        label: 'About',
        subtitle: 'Privacy & offline',
        color: AppColors.purpleDark,
        onTap: _showAbout,
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text('Settings',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
            children: tiles,
          ),
        ],
      ),
    );
  }
}

/// A single rounded Settings tile: a two-tone Iconsax glyph in a soft tinted
/// circle, a bold label, and a small muted subtitle — the grid card from the
/// reference.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.outline,
    required this.bold,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  final IconData outline;
  final IconData bold;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: color),
                        )
                      : ReminderGlyph(
                          outline: outline,
                          bold: bold,
                          color: color,
                          size: 28),
                ),
                const SizedBox(height: 12),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
