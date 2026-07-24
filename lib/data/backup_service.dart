// Private fields with public constructor names, intentionally.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/completion_record.dart';
import '../models/reminder_item.dart';
import 'app_settings.dart';
import 'reminder_repository.dart';

/// Local, offline backup & restore — export everything to a JSON file the user
/// can save/share, and import it back on the same or another phone. No server,
/// no account (as required by CLAUDE.md); "Restore" is a file import.
class BackupService {
  BackupService({
    required Box<ReminderItem> box,
    required AppSettings settings,
    required ReminderRepository repository,
  })  : _box = box,
        _settings = settings,
        _repository = repository;

  final Box<ReminderItem> _box;
  final AppSettings _settings;
  final ReminderRepository _repository;

  static const int _formatVersion = 1;

  Map<String, dynamic> _itemToJson(ReminderItem i) => {
        'id': i.id,
        'title': i.title,
        'categoryName': i.categoryName,
        'notes': i.notes,
        'nextDueDate': i.nextDueDate.toIso8601String(),
        'recurrenceTypeIndex': i.recurrenceTypeIndex,
        'recurrenceInterval': i.recurrenceInterval,
        'leadTimes': i.leadTimes,
        'notificationHour': i.notificationHour,
        'notificationMinute': i.notificationMinute,
        'isActive': i.isActive,
        'lastCompletedDate': i.lastCompletedDate?.toIso8601String(),
        'notificationBaseId': i.notificationBaseId,
        'snoozedUntil': i.snoozedUntil?.toIso8601String(),
        'escalateWhenOverdue': i.escalateWhenOverdue,
        'completions': i.completions
            .map((c) => {
                  'completedDate': c.completedDate.toIso8601String(),
                  'dueDate': c.dueDate.toIso8601String(),
                })
            .toList(),
      };

  ReminderItem _itemFromJson(Map<String, dynamic> j) => ReminderItem(
        id: j['id'] as String,
        title: j['title'] as String,
        categoryName: j['categoryName'] as String,
        notes: j['notes'] as String?,
        nextDueDate: DateTime.parse(j['nextDueDate'] as String),
        recurrenceTypeIndex: j['recurrenceTypeIndex'] as int,
        recurrenceInterval: j['recurrenceInterval'] as int,
        leadTimes: (j['leadTimes'] as List).map((e) => e as int).toList(),
        notificationHour: j['notificationHour'] as int?,
        notificationMinute: j['notificationMinute'] as int?,
        isActive: j['isActive'] as bool? ?? true,
        lastCompletedDate: j['lastCompletedDate'] == null
            ? null
            : DateTime.parse(j['lastCompletedDate'] as String),
        notificationBaseId: j['notificationBaseId'] as int,
        snoozedUntil: j['snoozedUntil'] == null
            ? null
            : DateTime.parse(j['snoozedUntil'] as String),
        escalateWhenOverdue: j['escalateWhenOverdue'] as bool? ?? true,
        completions: ((j['completions'] as List?) ?? [])
            .map((e) => CompletionRecord(
                  completedDate:
                      DateTime.parse((e as Map)['completedDate'] as String),
                  dueDate: DateTime.parse(e['dueDate'] as String),
                ))
            .toList(),
      );

  /// Serializes everything and opens the share sheet so the user can save the
  /// backup file wherever they like (Files, Drive, email…).
  Future<void> exportToShareSheet() async {
    final data = {
      'app': 'remindly',
      'formatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'defaultHour': _settings.defaultHour,
        'defaultMinute': _settings.defaultMinute,
        'defaultLeadDays': _settings.defaultLeadDays,
        'displayName': _settings.displayName,
      },
      'reminders': _box.values.map(_itemToJson).toList(),
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/remindly-backup-$stamp.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Remindly backup',
        text: 'Remindly backup ($stamp)',
      ),
    );
  }

  /// Lets the user pick a backup file and restores it, replacing current data.
  /// Returns the number of reminders imported, or null if cancelled.
  Future<int?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    String content;
    if (picked.bytes != null) {
      content = utf8.decode(picked.bytes!);
    } else if (picked.path != null) {
      content = await File(picked.path!).readAsString();
    } else {
      throw const FormatException('Could not read the selected file.');
    }

    final data = jsonDecode(content) as Map<String, dynamic>;
    if (data['app'] != 'remindly') {
      throw const FormatException('This is not a Remindly backup file.');
    }

    final reminders = (data['reminders'] as List)
        .map((e) => _itemFromJson(e as Map<String, dynamic>))
        .toList();

    final settings = data['settings'] as Map<String, dynamic>?;
    if (settings != null) {
      _settings.defaultHour = settings['defaultHour'] as int? ?? 9;
      _settings.defaultMinute = settings['defaultMinute'] as int? ?? 0;
      _settings.defaultLeadDays = settings['defaultLeadDays'] as int? ?? 7;
      _settings.displayName = settings['displayName'] as String? ?? '';
    }

    await _box.clear();
    for (final item in reminders) {
      await _box.put(item.id, item);
    }
    await _repository.reconcileAll();
    return reminders.length;
  }
}
