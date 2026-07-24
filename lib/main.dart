import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/app_settings.dart';
import 'data/reminder_repository.dart';
import 'models/reminder_item.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

/// Lets a tapped notification navigate to the right item from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage (source of truth). No server, no network.
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderItemAdapter());
  final remindersBox =
      await Hive.openBox<ReminderItem>(ReminderRepository.boxName);
  final settingsBox = await Hive.openBox(AppSettings.boxName);

  final settings = AppSettings(settingsBox);
  final notifications = NotificationService.instance;
  await notifications.init();

  final repository = ReminderRepository(
    box: remindersBox,
    settings: settings,
    notifications: notifications,
  );

  // Route notification taps to the item's editor.
  notifications.onSelectItem = (itemId) {
    final item = repository.byId(itemId);
    if (item != null) homeKey.currentState?.openEditor(item);
  };

  // Notifications are derived state — rebuild the whole schedule from storage
  // on every launch (also covers reboot, since local schedules are cleared).
  await repository.reconcileAll();

  runApp(ReminderApp(repository: repository, settings: settings));

  // Ask for permissions after first frame so the prompt has a UI context.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await notifications.requestPermissions();
    // If the app was launched by tapping a notification while terminated,
    // open that item.
    final launchId = await notifications.initialLaunchItemId();
    if (launchId != null) {
      final item = repository.byId(launchId);
      if (item != null) homeKey.currentState?.openEditor(item);
    }
  });
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({
    super.key,
    required this.repository,
    required this.settings,
  });

  final ReminderRepository repository;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5));
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E88E5),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Reminders',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      home: HomeScreen(
        key: homeKey,
        repository: repository,
        settings: settings,
      ),
    );
  }
}
