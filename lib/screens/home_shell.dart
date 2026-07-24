import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/backup_service.dart';
import '../data/reminder_repository.dart';
import '../models/reminder_item.dart';
import '../theme/app_theme.dart';
import 'add_edit_screen.dart';
import 'calendar_screen.dart';
import 'detail_screen.dart';
import 'done_screen.dart';
import 'settings_screen.dart';
import 'upcoming_screen.dart';

/// Root of the app after welcome: four tabs (Upcoming, Calendar, Done, Settings)
/// with a raised center "+" that opens the New Reminder form.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.settings,
    required this.backupService,
  });

  final ReminderRepository repository;
  final AppSettings settings;
  final BackupService backupService;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _tab = 0; // 0 Upcoming, 1 Calendar, 2 Done, 3 Settings

  /// Opens the detail screen for an item — used by notification taps.
  void openItem(ReminderItem item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DetailScreen(
        repository: widget.repository,
        settings: widget.settings,
        item: item,
      ),
    ));
  }

  void _openAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditScreen(
        repository: widget.repository,
        settings: widget.settings,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      UpcomingScreen(repository: widget.repository, settings: widget.settings),
      CalendarScreen(repository: widget.repository, settings: widget.settings),
      DoneScreen(repository: widget.repository),
      SettingsScreen(
        repository: widget.repository,
        settings: widget.settings,
        backupService: widget.backupService,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _BottomBar(
        current: _tab,
        onSelect: (i) => setState(() => _tab = i),
        onAdd: _openAdd,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(
                icon: Icons.grid_view_rounded,
                active: current == 0,
                onTap: () => onSelect(0),
              ),
              _NavIcon(
                icon: Icons.calendar_today_rounded,
                active: current == 1,
                onTap: () => onSelect(1),
              ),
              _AddButton(onTap: onAdd),
              _NavIcon(
                icon: Icons.check_rounded,
                active: current == 2,
                onTap: () => onSelect(2),
              ),
              _NavIcon(
                icon: Icons.settings_rounded,
                active: current == 3,
                onTap: () => onSelect(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon(
      {required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: active
            ? AppColors.purple
            : theme.colorScheme.onSurface.withValues(alpha: 0.35),
        size: 26,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}
