import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/app_settings.dart';
import 'data/backup_service.dart';
import 'data/reminder_repository.dart';
import 'models/completion_record.dart';
import 'models/reminder_item.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/google_calendar_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

/// Lets a tapped notification navigate to the right item from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<HomeShellState> shellKey = GlobalKey<HomeShellState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage (source of truth). No server, no network.
  await Hive.initFlutter();
  Hive.registerAdapter(CompletionRecordAdapter());
  Hive.registerAdapter(ReminderItemAdapter());
  final remindersBox =
      await Hive.openBox<ReminderItem>(ReminderRepository.boxName);
  final settingsBox = await Hive.openBox(AppSettings.boxName);

  final settings = AppSettings(settingsBox);
  final notifications = NotificationService.instance;
  await notifications.init();

  // Optional Google Calendar mirror (opt-in). init() is a no-op until an OAuth
  // client id is configured, so the app runs fine without it.
  final calendar = GoogleCalendarService.instance;
  await calendar.init();

  final repository = ReminderRepository(
    box: remindersBox,
    settings: settings,
    notifications: notifications,
    calendar: calendar,
  );
  final backupService = BackupService(
    box: remindersBox,
    settings: settings,
    repository: repository,
  );

  // Route notification taps to the item's detail screen.
  notifications.onSelectItem = (itemId) {
    final item = repository.byId(itemId);
    if (item != null) shellKey.currentState?.openItem(item);
  };

  // Notifications are derived state — rebuild the whole schedule from storage
  // on every launch (also covers reboot, since local schedules are cleared).
  await repository.reconcileAll();

  runApp(ReminderApp(
    repository: repository,
    settings: settings,
    backupService: backupService,
  ));

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await notifications.requestPermissions();
    final launchId = await notifications.initialLaunchItemId();
    if (launchId != null) {
      final item = repository.byId(launchId);
      if (item != null) shellKey.currentState?.openItem(item);
    }
  });
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({
    super.key,
    required this.repository,
    required this.settings,
    required this.backupService,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final BackupService backupService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remindly',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: _RootGate(
        repository: repository,
        settings: settings,
        backupService: backupService,
      ),
    );
  }
}

/// Shows the one-time welcome on first launch, then the app shell.
class _RootGate extends StatefulWidget {
  const _RootGate({
    required this.repository,
    required this.settings,
    required this.backupService,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final BackupService backupService;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late bool _showWelcome = !widget.settings.hasSeenWelcome;

  void _finishWelcome() {
    widget.settings.hasSeenWelcome = true;
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return WelcomeScreen(
        onGetStarted: _finishWelcome,
        backupService: widget.backupService,
      );
    }
    return HomeShell(
      key: shellKey,
      repository: widget.repository,
      settings: widget.settings,
      backupService: widget.backupService,
    );
  }
}
