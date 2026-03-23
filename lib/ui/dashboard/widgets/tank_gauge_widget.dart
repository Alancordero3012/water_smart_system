import 'dart:math';
import 'package:flutter/material.dart';

/// Compact animated tank gauge with wave effect and integrated info.
class AnimatedTankWidget extends StatefulWidget {
  final String label;
  final double level; // 0-100
  final Color color;
  final IconData icon;
  final double maxVolumeLiters;

  const AnimatedTankWidget({
    super.key,
    required this.label,
    required this.level,
    required this.color,
    required this.icon,
    this.maxVolumeLiters = 1000,
  });

  @override
  State<AnimatedTankWidget> createState() => _AnimatedTankWidgetState();
}

class _AnimatedTankWidgetState extends State<AnimatedTankWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeLevel = widget.level.clamp(0.0, 100.0);
    final volumeL = (safeLevel / 100 * widget.maxVolumeLiters).toInt();

    Color statusColor;
    if (safeLevel > 60) {
      statusColor = widget.color;
    } else if (safeLevel > 25) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(50), width: 1),
      ),
      child: Column(
        children: [
          // Header with label + reading inline
          Row(
            children: [
              Icon(widget.icon, color: statusColor, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(150),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '~$volumeL L',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withAlpha(80),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Tank visualization
          Expanded(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _TankWavePainter(
                      level: safeLevel / 100,
                      wavePhase: _waveController.value * 2 * pi,
                      color: statusColor,
                    ),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Percentage
          Text(
            '${safeLevel.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontFamily: 'monospace',
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TankWavePainter extends CustomPainter {
  final double level;
  final double wavePhase;
  final Color color;

  _TankWavePainter({
    required this.level,
    required this.wavePhase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0A0A1A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    if (level <= 0) return;

    final waterTop = size.height * (1 - level);
    final wavePath = Path();
    wavePath.moveTo(0, waterTop);

    final waveHeight = 2.0 + level * 3;
    for (double x = 0; x <= size.width; x++) {
      final y = waterTop +
          sin((x / size.width * 2 * pi) + wavePhase) * waveHeight +
          cos((x / size.width * 3 * pi) + wavePhase * 0.7) * waveHeight * 0.4;
      wavePath.lineTo(x, y);
    }

    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final waterPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(160), color.withAlpha(80)],
      ).createShader(
          Rect.fromLTWH(0, waterTop, size.width, size.height - waterTop));

    canvas.drawPath(wavePath, waterPaint);

    // Scale marks
    final markPaint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.1, y), markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TankWavePainter old) =>
      old.level != level || old.wavePhase != wavePhase || old.color != color;
}
