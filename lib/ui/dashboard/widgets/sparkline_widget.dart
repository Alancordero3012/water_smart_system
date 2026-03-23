import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Smooth sparkline chart — thick line, gradient fill, cubic bezier smoothing.
/// Animates the data list changes via AnimatedBuilder on the parent.
class SparklineWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final double height;

  const SparklineWidget({
    super.key,
    required this.data,
    required this.color,
    this.strokeWidth = 2.5,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return SizedBox(height: height);
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklinePainter(
            data: List.unmodifiable(data),
            color: color,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce((a, b) => a < b ? a : b);
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final effectiveRange = range < 0.01 ? 1.0 : range;

    // Compute normalised points (5% vertical padding top and bottom)
    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final norm = (data[i] - minVal) / effectiveRange;
      final y = size.height - (norm * size.height * 0.90) - size.height * 0.05;
      pts.add(Offset(x, y));
    }

    // Catmull-Rom → cubic bezier path (smooth)
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // Gradient fill under the curve (~12% opacity)
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          [color.withAlpha(35), color.withAlpha(4)],
        ),
    );

    // Stroke — thicker, glow-like
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withAlpha(210)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );

    // Terminal dot (current value)
    if (pts.isNotEmpty) {
      final last = pts.last;
      canvas.drawCircle(last, strokeWidth + 1, Paint()..color = color);
      // Outer glow ring
      canvas.drawCircle(
        last,
        strokeWidth + 2.5,
        Paint()
          ..color = color.withAlpha(50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color || old.strokeWidth != strokeWidth;
}
