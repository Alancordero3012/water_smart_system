import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/auth_provider.dart';
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
    final state     = ref.watch(processedSystemStateProvider);
    final repo      = ref.read(waterDataRepositoryProvider);
    final authState = ref.watch(authProvider);
    final canControl = authState.user?.rol != 'viewer'; // viewer = solo lectura

    // Escuchar bloqueos de interlock del backend
    ref.listen(interlockStreamProvider, (_, next) {
      next.whenData((msg) {
        AppNotifications.show(
          context,
          '🔒 $msg',
          type: NotificationType.warning,
        );
      });
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de solo lectura para observadores
          if (!canControl) const _ReadOnlyBanner(),

          _SectionHeader(title: 'CONTROL DE FUENTES', icon: Icons.power),
          const SizedBox(height: 10),

          // ── Fuente 1 + Fuente 2 cards ─────────────────────────────────
          Row(
            children: [
              Expanded(child: _FuenteCard(type: FuenteType.fuente1, canControl: canControl)),
              const SizedBox(width: 10),
              Expanded(child: _FuenteCard(type: FuenteType.fuente2, canControl: canControl)),
            ],
          ),

          const SizedBox(height: 24),

          // ── Botón Industrial Bomba ────────────────────────────────────
          _SectionHeader(title: 'CONTROL BOMBA PRINCIPAL', icon: Icons.power_settings_new),
          const SizedBox(height: 20),
          _BombaSection(canControl: canControl),

          const SizedBox(height: 24),
          _SectionHeader(title: 'FUENTE DE AGUA', icon: Icons.water_drop),
          const SizedBox(height: 10),

          _SourceSegmentedButton(
            current: state.activeSource,
            canControl: canControl,
            onChanged: canControl ? (v) {
              repo.sendCommand('source', v);
              AppNotifications.show(
                context,
                'Fuente cambiada → ${v == "lluvia" ? "Tanque Lluvia" : "Red Pública"}',
                type: NotificationType.info,
              );
            } : null,
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
                // DESACTIVADO: sensor de turbidez no verificado en hardware actual
                // _MetricRow(
                //   label: 'Turbidez',
                //   valueWidget: GlowValue(
                //     rawValue: state.turbidity,
                //     unit: 'NTU',
                //     color: state.turbidity > 50
                //         ? Colors.redAccent
                //         : const Color(0xFF00E5FF),
                //     fontSize: 18,
                //   ),
                // ),
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

class _FuenteCard extends ConsumerStatefulWidget {
  final FuenteType type;
  final bool canControl;
  const _FuenteCard({required this.type, this.canControl = true});

  @override
  ConsumerState<_FuenteCard> createState() => _FuenteCardState();
}

class _FuenteCardState extends ConsumerState<_FuenteCard> {
  @override
  Widget build(BuildContext context) {
    final actuatorState = ref.watch(actuatorProvider);
    final isTestMode    = ref.watch(testModeProvider);

    final bool isActive = switch (widget.type) {
      FuenteType.fuente1 => actuatorState.fuente1Active,
      FuenteType.fuente2 => actuatorState.fuente2Active,
    };
    final bool isPending = actuatorState.pending == widget.type;

    final Color activeColor = switch (widget.type) {
      FuenteType.fuente1 => const Color(0xFF00E676),
      FuenteType.fuente2 => const Color(0xFF00E5FF),
    };
    final Color darkAccent = switch (widget.type) {
      FuenteType.fuente1 => const Color(0xFF00A852),
      FuenteType.fuente2 => const Color(0xFF0090A8),
    };
    final IconData icon = switch (widget.type) {
      FuenteType.fuente1 => Icons.power_settings_new,
      FuenteType.fuente2 => Icons.water_drop_outlined,
    };
    final String label = switch (widget.type) {
      FuenteType.fuente1 => 'Fuente Calle',
      FuenteType.fuente2 => 'Fuente Lluvia',
    };
    final String sublabel = switch (widget.type) {
      FuenteType.fuente1 => 'Red Pública',
      FuenteType.fuente2 => 'Tanque de Lluvia',
    };

    final Color borderColor = isPending
        ? Colors.orange
        : isActive
            ? activeColor
            : Colors.white.withAlpha(20);

    return GestureDetector(
      onTap: (isPending || !widget.canControl)
          ? null
          : () {
              ref.read(actuatorProvider.notifier).toggle(
                widget.type,
                bypassInterlock: isTestMode,
              );
              final fuenteName = widget.type == FuenteType.fuente1
                  ? 'Fuente Calle'
                  : 'Fuente Lluvia';
              AppNotifications.show(
                context,
                '$fuenteName → ${isActive ? "apagando Bomba + Solenoide" : "encendiendo Bomba + Solenoide"}'
                '${isTestMode ? " [MODO PRUEBA]" : ""}',
                type: NotificationType.info,
              );
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeColor.withAlpha(28),
                    darkAccent.withAlpha(10),
                    const Color(0xFF13131A),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1E2E), Color(0xFF13131A)],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor.withAlpha(isPending ? 160 : isActive ? 90 : 25),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(35),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + status pill ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container with glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isActive
                        ? activeColor.withAlpha(30)
                        : Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isActive
                          ? activeColor.withAlpha(60)
                          : Colors.white.withAlpha(12),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: activeColor.withAlpha(50),
                              blurRadius: 12,
                              spreadRadius: -2,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? activeColor : Colors.white38,
                    size: 22,
                  ),
                ),
                const Spacer(),
                // Status pill / pending indicator
                if (isPending)
                  _PendingPill()
                else
                  _StatusPill(isActive: isActive, color: activeColor),
              ],
            ),

            const SizedBox(height: 16),

            // ── Label ────────────────────────────────────────────────────
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white.withAlpha(230) : Colors.white.withAlpha(140),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sublabel,
              style: TextStyle(
                color: Colors.white.withAlpha(60),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),

            // ── Active indicator bar + badges ─────────────────────────
            if (isActive) ...[
              const SizedBox(height: 14),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [activeColor.withAlpha(180), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              _DualActuatorBadge(color: activeColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status pill widget ─────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final bool isActive;
  final Color color;
  const _StatusPill({required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(22) : Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color.withAlpha(80) : Colors.white.withAlpha(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white30,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [BoxShadow(color: color.withAlpha(120), blurRadius: 5)]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ACTIVA' : 'INACTIVA',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isActive ? color : Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending pill widget ────────────────────────────────────────────────────────

class _PendingPill extends StatefulWidget {
  const _PendingPill();

  @override
  State<_PendingPill> createState() => _PendingPillState();
}

class _PendingPillState extends State<_PendingPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _fade = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'SYNC',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.orange,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dual actuator confirmation badge ──────────────────────────────────────────

class _DualActuatorBadge extends StatelessWidget {
  final Color color;
  const _DualActuatorBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActuatorDot(label: 'BOMBA', color: const Color(0xFF00E676)),
        const SizedBox(width: 6),
        _ActuatorDot(label: 'SOLENOIDE', color: const Color(0xFF00E5FF)),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color.withAlpha(200),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source selector ───────────────────────────────────────────────────────────

class _SourceSegmentedButton extends StatelessWidget {
  final String current;
  final ValueChanged<String>? onChanged;
  final bool canControl;

  const _SourceSegmentedButton({
    required this.current,
    required this.canControl,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          _SourceOption(
            value: 'lluvia',
            label: 'Tanque Lluvia',
            icon: Icons.water_drop_outlined,
            activeColor: const Color(0xFF00B4D8),
            isSelected: current == 'lluvia',
            onTap: canControl ? () => onChanged?.call('lluvia') : null,
          ),
          const SizedBox(width: 5),
          _SourceOption(
            value: 'calle',
            label: 'Red Pública',
            icon: Icons.location_city_outlined,
            activeColor: const Color(0xFFFFB74D),
            isSelected: current == 'calle',
            onTap: canControl ? () => onChanged?.call('calle') : null,
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color activeColor;
  final bool isSelected;
  final VoidCallback? onTap; // null = deshabilitado (viewer)

  const _SourceOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: isSelected ? activeColor.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? activeColor.withAlpha(80) : Colors.transparent,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withAlpha(35),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? activeColor : Colors.white30,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? activeColor : Colors.white38,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF).withAlpha(18),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF00E5FF).withAlpha(200)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(110),
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5FF).withAlpha(60),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Bomba Section container ───────────────────────────────────────────────────

/// Contenedor con estética de panel de control industrial para el gran botón.
class _BombaSection extends StatelessWidget {
  final bool canControl;
  const _BombaSection({this.canControl = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
          Center(child: BombaButton(canControl: canControl)),

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

// ── Read-Only Banner ──────────────────────────────────────────────────────────

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF9C88FF).withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9C88FF).withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined,
              color: const Color(0xFF9C88FF).withAlpha(200), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo observador — solo lectura. No tienes permisos para controlar actuadores.',
              style: TextStyle(
                color: const Color(0xFF9C88FF).withAlpha(200),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
