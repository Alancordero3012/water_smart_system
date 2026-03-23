import 'package:flutter/material.dart';

/// Compact telemetry card for the dashboard grid.
/// Includes header, sparkline slot, value with glow, and optional status pill.
class TelemetryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final Widget? sparkline;
  final Widget valueWidget;

  const TelemetryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.valueWidget,
    this.trailing,
    this.sparkline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(130),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),

          // Sparkline (fills available space)
          if (sparkline != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: sparkline!,
              ),
            )
          else
            const Spacer(),

          // Value
          valueWidget,
        ],
      ),
    );
  }
}

/// Status pill indicator
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Actuator status row with LED indicator
class ActuatorStatus extends StatelessWidget {
  final String label;
  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;

  const ActuatorStatus({
    super.key,
    required this.label,
    required this.isActive,
    this.activeLabel = 'ON',
    this.inactiveLabel = 'OFF',
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.greenAccent : Colors.redAccent;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withAlpha(170),
            ),
          ),
        ),
        Text(
          isActive ? activeLabel : inactiveLabel,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
