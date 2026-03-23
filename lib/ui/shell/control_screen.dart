import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../dashboard/widgets/glow_value.dart';
import '../shared/app_notifications.dart';

/// Full Control tab — actuator switches, source selector, live metrics.
class ControlScreen extends ConsumerWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(processedSystemStateProvider);
    final repo  = ref.read(waterDataRepositoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'ACTUADORES', icon: Icons.power),
          const SizedBox(height: 10),

          // Actuator cards
          Row(
            children: [
              Expanded(
                child: _ActuatorCard(
                  label: 'Bomba',
                  subtitle: state.isPumpActive ? 'ENCENDIDA' : 'APAGADA',
                  icon: Icons.power_settings_new,
                  isActive: state.isPumpActive,
                  activeColor: const Color(0xFF00E676),
                  onChanged: (v) {
                    repo.sendCommand('pump', v ? 'ON' : 'OFF');
                    AppNotifications.show(
                      context,
                      'Bomba ${v ? "encendida" : "apagada"}',
                      type: v
                          ? NotificationType.success
                          : NotificationType.warning,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActuatorCard(
                  label: 'Solenoide',
                  subtitle: state.isSolenoidOpen ? 'ABIERTA' : 'CERRADA',
                  icon: Icons.adjust,
                  isActive: state.isSolenoidOpen,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (v) {
                    repo.sendCommand('solenoid', v ? 'OPEN' : 'CLOSED');
                    AppNotifications.show(
                      context,
                      'Solenoide ${v ? "abierta" : "cerrada"}',
                      type: v
                          ? NotificationType.success
                          : NotificationType.warning,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'FUENTE DE AGUA', icon: Icons.water_drop),
          const SizedBox(height: 10),

          // Segmented source selector
          _SourceSegmentedButton(
            current: state.activeSource,
            onChanged: (v) {
              repo.sendCommand('source', v);
              AppNotifications.show(
                context,
                'Fuente cambiada → ${v == "lluvia" ? "Tanque Lluvia" : "Red Pública"}',
                type: NotificationType.info,
              );
            },
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'LECTURAS EN VIVO', icon: Icons.monitor_heart),
          const SizedBox(height: 10),

          // Live metrics card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Column(
              children: [
                _MetricRow(
                  label: 'Presión',
                  valueWidget: GlowValue(
                    rawValue: state.streetPressure,
                    unit: 'PSI',
                    color: state.streetPressure < 15
                        ? Colors.redAccent
                        : const Color(0xFF00E5FF),
                    fontSize: 18,
                  ),
                ),
                _divider(),
                _MetricRow(
                  label: 'Caudal',
                  valueWidget: GlowValue(
                    rawValue: state.flowRate,
                    unit: 'L/min',
                    color: state.flowRate > 0
                        ? const Color(0xFF00E676)
                        : Colors.grey,
                    fontSize: 18,
                  ),
                ),
                _divider(),
                _MetricRow(
                  label: 'Turbidez',
                  valueWidget: GlowValue(
                    rawValue: state.turbidity,
                    unit: 'NTU',
                    color: state.turbidity > 50
                        ? Colors.redAccent
                        : const Color(0xFF00E5FF),
                    fontSize: 18,
                  ),
                ),
                _divider(),
                _MetricRow(
                  label: 'Fuente activa',
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.activeSource == 'lluvia'
                            ? Icons.cloud_queue
                            : Icons.location_city,
                        size: 14,
                        color: state.activeSource == 'lluvia'
                            ? const Color(0xFF00B4D8)
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        state.activeSource.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: state.activeSource == 'lluvia'
                              ? const Color(0xFF00B4D8)
                              : Colors.orange,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        height: 1,
        color: Colors.white.withAlpha(8),
      );
}

// ── Actuator card ─────────────────────────────────────────────────────

class _ActuatorCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ActuatorCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : Colors.white24;
    return GestureDetector(
      onTap: () => onChanged(!isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(12) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(70), width: 1.5),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withAlpha(18), blurRadius: 14)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withAlpha(18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: isActive,
                  activeTrackColor: activeColor,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Source selector ───────────────────────────────────────────────────

class _SourceSegmentedButton extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SourceSegmentedButton({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: 'lluvia',
          label: Text('Tanque Lluvia'),
          icon: Icon(Icons.cloud_queue, size: 16),
        ),
        ButtonSegment(
          value: 'calle',
          label: Text('Red Pública'),
          icon: Icon(Icons.location_city, size: 16),
        ),
      ],
      selected: {current},
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(vertical: -1),
        side: WidgetStateProperty.all(
          BorderSide(color: Colors.white.withAlpha(20)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return Colors.white54;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return current == 'lluvia'
                ? const Color(0xFF00B4D8)
                : Colors.orange;
          }
          return const Color(0xFF1A1A2E);
        }),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      onSelectionChanged: (sel) => onChanged(sel.first),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  final String label;
  final Widget valueWidget;

  const _MetricRow({required this.label, required this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 12,
            ),
          ),
        ),
        valueWidget,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF00E5FF).withAlpha(110)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(70),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: Colors.white.withAlpha(10)),
        ),
      ],
    );
  }
}
