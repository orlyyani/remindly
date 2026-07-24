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
    return MaterialApp(
      title: 'Reminders',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(
        key: homeKey,
        repository: repository,
        settings: settings,
      ),
    );
  }
}

/// Warm-orange Material 3 theme with rounded cards, pill buttons and soft
/// inputs — the look drawn from the reminder-app inspirations. Works in both
/// light and dark mode.
ThemeData _buildTheme(Brightness brightness) {
  const seed = Color(0xFFF57C00); // warm orange
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
