import 'package:flutter/material.dart';

import '../data/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alarm_clock.dart';

/// A one-time, skippable welcome shown on first launch. "Get Started" drops
/// straight into the list (not a wall). "Restore" imports a local backup file.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.backupService,
  });

  final VoidCallback onGetStarted;
  final BackupService backupService;

  Future<void> _restore(BuildContext context) async {
    try {
      final count = await backupService.importFromFile();
      if (count == null) return; // cancelled
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored $count reminder(s).')),
        );
      }
      onGetStarted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t restore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Welcome to\n'),
                  TextSpan(
                    text: 'Remindly',
                    style: TextStyle(color: theme.colorScheme.secondary),
                  ),
                  const TextSpan(text: ' reminder app'),
                ]),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
              ),
              const SizedBox(height: 16),
              Text(
                'One place for oil changes, renewals and birthdays. '
                'Add it once — we nudge you before it\'s due.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const AlarmClock(size: 190),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shadowColor:
                        theme.colorScheme.secondary.withValues(alpha: 0.5),
                  ),
                  child: const Text('Get Started  →'),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _restore(context),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Already set up on another phone? ',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55)),
                    ),
                    TextSpan(
                      text: 'Restore',
                      style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
