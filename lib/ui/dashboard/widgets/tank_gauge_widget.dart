import 'dart:math';
import 'package:flutter/material.dart';

/// Compact animated tank gauge with wave effect, reed-switch LEDs, and
/// an optional empty-tank warning.
class AnimatedTankWidget extends StatefulWidget {
  final String label;
  final double level; // 0-100
  final Color color;
  final IconData icon;
  final double maxVolumeLiters;

  // Individual reed-switch sensor states (null = hardware not connected yet)
  final bool? sensor0;    // true = agua detectada en S0  (0 %)
  final bool? sensor50;   // true = agua detectada en S50 (50%)
  final bool? sensor100;  // true = agua detectada en S100 (100%)

  const AnimatedTankWidget({
    super.key,
    required this.label,
    required this.level,
    required this.color,
    required this.icon,
    this.maxVolumeLiters = 1000,
    this.sensor0,
    this.sensor50,
    this.sensor100,
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

    // Only show sensor row when at least one value is reported by hardware
    final hasSensors = widget.sensor0 != null ||
        widget.sensor50 != null ||
        widget.sensor100 != null;
    final isEmpty = safeLevel == 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmpty ? Colors.redAccent.withAlpha(80) : statusColor.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with label + volume
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
              if (!isEmpty)
                Text(
                  '~$volumeL L',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withAlpha(80),
                    fontFamily: 'monospace',
                  ),
                )
              else
                // Pulsing VACÍO badge
                _EmptyBadge(),
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

          // Reed-switch LED row (only visible when hardware is connected)
          if (hasSensors) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SensorDot(label: 'S0',  active: widget.sensor0),
                const SizedBox(width: 4),
                _SensorDot(label: 'S50', active: widget.sensor50),
                const SizedBox(width: 4),
                _SensorDot(label: 'S100', active: widget.sensor100),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty tank pulsing badge ─────────────────────────────────────────────────

class _EmptyBadge extends StatefulWidget {
  @override
  State<_EmptyBadge> createState() => _EmptyBadgeState();
}

class _EmptyBadgeState extends State<_EmptyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.redAccent.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.redAccent.withAlpha(80), width: 1),
          ),
          child: const Text(
            'VACÍO',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reed-switch sensor LED dot ────────────────────────────────────────────────

class _SensorDot extends StatelessWidget {
  final String label;
  final bool? active; // null = no hardware data yet

  const _SensorDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active == null
        ? Colors.white24          // no data
        : active!
            ? const Color(0xFF00E676)  // agua detectada
            : Colors.white24;          // seco

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: active == true
                ? [BoxShadow(color: color.withAlpha(160), blurRadius: 5)]
                : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 6,
            color: color,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
