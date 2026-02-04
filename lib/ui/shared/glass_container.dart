import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.padding,
    this.borderRadius,
    // Ignoring opacity/blur params as we are moving to solid
    double opacity = 1.0,
    double blur = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Solid Dark Grey (Industrial)
        borderRadius:
            borderRadius ?? BorderRadius.circular(12), // Slightly less rounded
        border: Border.all(
          color: Colors.white24, // Clearer border
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
