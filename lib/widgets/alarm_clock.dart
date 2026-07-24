import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A friendly painted alarm clock — the app's mascot, used on the welcome and
/// New Reminder screens. Purely drawn (no image assets, no network), so it
/// stays crisp at any size and ships inside the app.
class AlarmClock extends StatelessWidget {
  const AlarmClock({super.key, this.size = 180});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AlarmClockPainter()),
    );
  }
}

class _AlarmClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.55);
    final r = w * 0.34;

    final purple = Paint()..color = AppColors.purple;
    final purpleStroke = Paint()
      ..color = AppColors.purple
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Bells
    final bellPaint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(c.dx - r * 0.7, c.dy - r), radius: r * 0.5),
      math.pi * 1.15, math.pi * 0.7, false, bellPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(c.dx + r * 0.7, c.dy - r), radius: r * 0.5),
      math.pi * 1.15, math.pi * 0.7, false, bellPaint,
    );

    // Feet
    purpleStroke.strokeWidth = w * 0.05;
    canvas.drawLine(Offset(c.dx - r * 0.55, c.dy + r * 0.9),
        Offset(c.dx - r * 0.85, c.dy + r * 1.15), purpleStroke);
    canvas.drawLine(Offset(c.dx + r * 0.55, c.dy + r * 0.9),
        Offset(c.dx + r * 0.85, c.dy + r * 1.15), purpleStroke);

    // Outer ring
    canvas.drawCircle(c, r, purple);
    // White face
    canvas.drawCircle(c, r * 0.78, Paint()..color = Colors.white);

    // Hands
    final hand = Paint()
      ..color = AppColors.orange
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, Offset(c.dx, c.dy - r * 0.5), hand); // minute (up)
    canvas.drawLine(c, Offset(c.dx + r * 0.42, c.dy + r * 0.18), hand); // hour
    canvas.drawCircle(c, w * 0.028, Paint()..color = AppColors.inkLight);

    // Decorative dots
    canvas.drawCircle(Offset(c.dx - r * 1.05, c.dy + r * 0.35), w * 0.028,
        Paint()..color = AppColors.orange);
    canvas.drawCircle(Offset(c.dx + r * 1.05, c.dy + r * 0.5), w * 0.035,
        Paint()..color = const Color(0xFFE86AA6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
