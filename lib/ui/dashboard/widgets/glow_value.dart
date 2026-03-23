import 'package:flutter/material.dart';

/// Smooth animated value display. Uses TweenAnimationBuilder so the
/// numeric reading slides to the new value rather than jumping.
class GlowValue extends StatelessWidget {
  final double rawValue; // numeric — for animation interpolation
  final String unit;
  final Color color;
  final double fontSize;
  final int decimalPlaces;

  const GlowValue({
    super.key,
    required this.rawValue,
    required this.unit,
    required this.color,
    this.fontSize = 24,
    this.decimalPlaces = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: rawValue),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowText(
              text: animatedValue.toStringAsFixed(decimalPlaces),
              color: color,
              fontSize: fontSize,
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: fontSize * 0.38,
                  color: color.withAlpha(140),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Static text with subtle text shadow glow.
class _GlowText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const _GlowText({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color,
        fontFamily: 'monospace',
        height: 1,
        shadows: [
          Shadow(color: color.withAlpha(55), blurRadius: 10),
        ],
      ),
    );
  }
}
