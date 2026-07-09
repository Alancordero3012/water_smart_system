import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/actuator_notifier.dart';
import '../dashboard/widgets/glow_value.dart';
import '../dashboard/widgets/bomba_button.dart';
import '../shared/app_notifications.dart';

/// Full Control tab — Fuente 1 / Fuente 2 switches (MQTT-confirmed), source
/// selector, and live telemetry metrics.
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
          _SectionHeader(title: 'CONTROL DE FUENTES', icon: Icons.power),
          const SizedBox(height: 10),

          // ── Fuente 1 + Fuente 2 cards ─────────────────────────────────
          const Row(
            children: [
              Expanded(child: _FuenteCard(type: FuenteType.fuente1)),
              SizedBox(width: 10),
              Expanded(child: _FuenteCard(type: FuenteType.fuente2)),
            ],
          ),

          const SizedBox(height: 24),

          // ── Botón Industrial Bomba ────────────────────────────────────
          _SectionHeader(title: 'CONTROL BOMBA PRINCIPAL', icon: Icons.power_settings_new),
          const SizedBox(height: 20),
          const _BombaSection(),

          const SizedBox(height: 24),
          _SectionHeader(title: 'FUENTE DE AGUA', icon: Icons.water_drop),
          const SizedBox(height: 10),

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

// ── MQTT-Confirmed Fuente Card ─────────────────────────────────────────────────

class _FuenteCard extends ConsumerWidget {
  final FuenteType type;
  const _FuenteCard({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actuatorState = ref.watch(actuatorProvider);

    final bool isActive = switch (type) {
      FuenteType.fuente1 => actuatorState.fuente1Active,
      FuenteType.fuente2 => actuatorState.fuente2Active,
    };
    final bool isPending = actuatorState.pending == type;

    final Color activeColor = switch (type) {
      FuenteType.fuente1 => const Color(0xFF00E676),
      FuenteType.fuente2 => const Color(0xFF00E5FF),
    };
    final IconData icon = switch (type) {
      FuenteType.fuente1 => Icons.power_settings_new,
      FuenteType.fuente2 => Icons.device_hub,
    };
    final String label = switch (type) {
      FuenteType.fuente1 => 'Fuente Calle',
      FuenteType.fuente2 => 'Fuente Lluvia',
    };
    final String subtitle = switch (type) {
      FuenteType.fuente1 => isActive ? 'ENCENDIDA' : 'APAGADA',
      FuenteType.fuente2 => isActive ? 'ENCENDIDA'  : 'APAGADA',
    };

    final Color color = isActive ? activeColor : Colors.white24;

    return GestureDetector(
      onTap: isPending
          ? null
          : () {
              ref.read(actuatorProvider.notifier).toggle(type);
              final fuenteName = type == FuenteType.fuente1 ? 'Fuente Calle' : 'Fuente Lluvia';
              AppNotifications.show(
                context,
                '$fuenteName → ${isActive ? "apagando Bomba + Solenoide" : "encendiendo Bomba + Solenoide"}',
                type: NotificationType.info,
              );
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withAlpha(12)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPending
                ? Colors.orange.withAlpha(80)
                : color.withAlpha(70),
            width: 1.5,
          ),
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
                  child: Icon(
                    icon,
                    color: color,
                    size: 18,
                  ),
                ),
                const Spacer(),
                if (isPending)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange.withAlpha(200),
                    ),
                  )
                else
                  Switch.adaptive(
                    value: isActive,
                    activeTrackColor: activeColor,
                    onChanged: isPending
                        ? null
                        : (_) => ref
                            .read(actuatorProvider.notifier)
                            .toggle(type),
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
              isPending ? 'CONFIRMANDO...' : subtitle,
              style: TextStyle(
                color: isPending ? Colors.orange : color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 6),
              _DualActuatorBadge(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dual actuator confirmation badge ──────────────────────────────────────────

class _DualActuatorBadge extends StatelessWidget {
  const _DualActuatorBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActuatorDot(label: 'B', color: const Color(0xFF00E676)),
        const SizedBox(width: 4),
        _ActuatorDot(label: 'S', color: const Color(0xFF00E5FF)),
      ],
    );
  }
}

class _ActuatorDot extends StatelessWidget {
  final String label;
  final Color color;
  const _ActuatorDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Source selector ───────────────────────────────────────────────────────────

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

// ── Shared helpers ────────────────────────────────────────────────────────────

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
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
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

// ── Bomba Section container ───────────────────────────────────────────────────

/// Contenedor con estética de panel de control industrial para el gran botón.
class _BombaSection extends StatelessWidget {
  const _BombaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        // Fondo tipo panel metálico oscuro con veta sutil
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C28), Color(0xFF13131A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Panel label top
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PANEL  Nº 01',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AGUA_IOT/ACTUADORES/BOMBA',
                  style: TextStyle(
                    fontSize: 7,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.18),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Gran botón centrado
          const Center(child: BombaButton()),

          const SizedBox(height: 20),

          // Línea divisoria técnica
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom spec row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SpecBadge(label: 'ID COMP', value: '6'),
              const SizedBox(width: 10),
              _SpecBadge(label: 'SEÑAL', value: '0 / 1'),
              const SizedBox(width: 10),
              _SpecBadge(label: 'PROTOCOLO', value: 'MQTT QoS1'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecBadge extends StatelessWidget {
  final String label;
  final String value;
  const _SpecBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 1,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.55),
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
