import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An animated launch screen: the Remindly logo springs + fades in, then the
/// "Remindly" wordmark rises beneath it. Shown once at app start, it calls
/// [onDone] when the intro finishes so the app can route on.
///
/// The logo's clock is purple, so this sits on the warm off-white brand
/// background (a purple backdrop would swallow the ring) — which also matches
/// the native splash, making the handoff seamless.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _wobble;
  late final Animation<double> _textFade;
  late final Animation<double> _textSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _logoFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _logoScale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ));
    // A gentle "the bell is ringing" tilt after the logo lands.
    _wobble = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _c,
      curve: const Interval(0.5, 0.8, curve: Curves.easeInOut),
    ));
    _textFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );
    _textSlide = Tween(begin: 18.0, end: 0.0).animate(CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
    ));

    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Let the finished frame breathe for a beat before routing on.
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoFade.value,
                  child: Transform.rotate(
                    angle: _wobble.value,
                    child: Transform.scale(scale: _logoScale.value, child: child),
                  ),
                );
              },
              child: Image.asset(
                'assets/icon/logo_transparent.png',
                width: 168,
                height: 168,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                return Opacity(
                  opacity: _textFade.value,
                  child: Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    'Remindly',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.purple,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Never forget what matters',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
