import 'package:flutter/material.dart';

/// Two-tone "bulk"-style illustration: the [bold] (filled) glyph faint
/// underneath and the [outline] (linear) glyph crisp on top, both in [color].
/// Reproduces the Iconsax Bulk look by layering the Bold + Linear variants
/// (the package ships no Bulk file), so it stays on-theme with the app's icons.
class ReminderGlyph extends StatelessWidget {
  const ReminderGlyph({
    super.key,
    required this.outline,
    required this.bold,
    required this.color,
    this.size = 28,
  });

  final IconData outline;
  final IconData bold;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(bold, color: color.withValues(alpha: 0.28), size: size),
          Icon(outline, color: color, size: size),
        ],
      ),
    );
  }
}
