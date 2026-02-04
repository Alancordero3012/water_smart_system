import 'package:flutter/material.dart';
import '../../shared/glass_container.dart';

class TankGaugeWidget extends StatelessWidget {
  final String label;
  final double level; // 0 to 100
  final Color color;
  final IconData icon;

  const TankGaugeWidget({
    super.key,
    required this.label,
    required this.level,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Clamping level between 0 and 100
    final double safeLevel = level.clamp(0.0, 100.0);
    final double normalizedLevel = safeLevel / 100.0;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background Track (Solid Dark)
                Container(
                  width: 24, // Thinner, more precise look
                  decoration: BoxDecoration(
                    color: const Color(0xFF101010), // Almost black track
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                ),
                // Foreground Fill (Solid Color)
                FractionallySizedBox(
                  heightFactor: normalizedLevel,
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: color, // Solid Neon Color
                      borderRadius: BorderRadius.only(
                        bottomLeft: const Radius.circular(4),
                        bottomRight: const Radius.circular(4),
                        topLeft: Radius.circular(
                          normalizedLevel > 0.95 ? 4 : 0,
                        ),
                        topRight: Radius.circular(
                          normalizedLevel > 0.95 ? 4 : 0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withAlpha(50),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
                // Measurement Lines (Industrial Ticks)
                IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      11,
                      (index) => Container(
                        // width: indeXXX % 5 == 0 ? 32 : 12, // Longer ticks every 50%? No, every 10%
                        // Actually just simple lines
                        width: 28,
                        height: 1,
                        color: Colors.black26,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${safeLevel.toInt()}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Monospace', // Tech look
            ),
          ),
        ],
      ),
    );
  }
}
