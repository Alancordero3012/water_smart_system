import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/models/water_system_state.dart';
import '../../data/services/bridge_health_service.dart';
import 'widgets/tank_gauge_widget.dart';
import 'widgets/telemetry_card.dart';
import 'widgets/sparkline_widget.dart';
import 'widgets/glow_value.dart';

/// Immersive dashboard body — lives inside IndexedStack in AppShell.
class DashboardBody extends ConsumerStatefulWidget {
  const DashboardBody({super.key});

  @override
  ConsumerState<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<DashboardBody> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // processedSystemStateProvider SIEMPRE emite un WaterSystemState
    // (valores en 0 por defecto). Nunca se queda en loading.
    final state       = ref.watch(processedSystemStateProvider);
    final asyncState  = ref.watch(waterSystemAsyncProvider);
    final history     = ref.watch(sparklineHistoryProvider);
    final isSimulation = ref.watch(useSimulationProvider);

    // Solo usamos asyncState para detectar error real del bridge
    final hasError = asyncState is AsyncError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'TELEMETRÍA EN VIVO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withAlpha(55),
              letterSpacing: 2.5,
            ),
          ),
        ),

        // ── Bridge Status Banner (simulation mode only) ─────────────
        if (isSimulation) const _BridgeStatusBanner(),

        const SizedBox(height: 6),

        // ── Tanks — siempre visible, 0% si aún no hay datos ────────
        _buildTanks(state),

        const SizedBox(height: 10),

        // ── Actuator status bar — siempre visible ──────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ActuatorStatusBar(state: state),
        ),

        const SizedBox(height: 10),

        // ── "SENSORES" label + dots ────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'SENSORES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withAlpha(55),
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.only(left: 5),
                    width: active ? 16 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ── EXPANDED Carousel — siempre visible, error solo si bridge falla
        Expanded(
          child: hasError
              ? _buildBridgeErrorState(asyncState.error.toString())
              : Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        _card(_buildPressureCard(state, history)),
                        _card(_buildFlowCard(state, history)),
                        _card(_buildTurbidityCard(state, history)),
                      ],
                    ),
                    if (_currentPage > 0)
                      _HoverArrow(
                        alignment: Alignment.centerLeft,
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                    if (_currentPage < 2)
                      _HoverArrow(
                        alignment: Alignment.centerRight,
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                  ],
                ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBridgeErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () =>
                  ref.read(bridgeHealthProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      );

  Widget _buildPressureCard(WaterSystemState s, SparklineHistory h) {
    final isLow = s.streetPressure < 15;
    final color = isLow ? Colors.redAccent : const Color(0xFF00E5FF);
    return TelemetryCard(
      title: 'PRESIÓN   1 / 3',
      icon: Icons.speed,
      color: color,
      trailing: StatusPill(
        label: isLow ? 'BAJA' : 'NORMAL',
        color: isLow ? Colors.redAccent : Colors.greenAccent,
      ),
      sparkline: SparklineWidget(data: List.from(h.pressure), color: color),
      valueWidget: GlowValue(
          rawValue: s.streetPressure, unit: 'PSI', color: color, fontSize: 36),
    );
  }

  Widget _buildFlowCard(WaterSystemState s, SparklineHistory h) {
    final isActive = s.flowRate > 0;
    final color = isActive ? const Color(0xFF00E676) : Colors.grey;
    return TelemetryCard(
      title: 'CAUDAL   2 / 3',
      icon: Icons.waves,
      color: color,
      trailing: StatusPill(
        label: isActive ? 'ACTIVO' : 'PARADO',
        color: isActive ? Colors.greenAccent : Colors.grey,
      ),
      sparkline: SparklineWidget(data: List.from(h.flow), color: color),
      valueWidget: GlowValue(
          rawValue: s.flowRate, unit: 'L/min', color: color, fontSize: 36),
    );
  }

  Widget _buildTurbidityCard(WaterSystemState s, SparklineHistory h) {
    final color = s.turbidity > 50
        ? Colors.redAccent
        : s.turbidity > 20
            ? Colors.orange
            : const Color(0xFF00E5FF);
    final label = s.turbidity > 50
        ? 'TURBIO'
        : s.turbidity > 20
            ? 'MODERADO'
            : 'CRISTALINO';
    return TelemetryCard(
      title: 'TURBIDEZ   3 / 3',
      icon: Icons.opacity,
      color: color,
      trailing: StatusPill(label: label, color: color),
      sparkline: SparklineWidget(data: List.from(h.turbidity), color: color),
      valueWidget: GlowValue(
          rawValue: s.turbidity, unit: 'NTU', color: color, fontSize: 36),
    );
  }

  Widget _buildTanks(WaterSystemState state) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 155,
          child: Row(
            children: [
              Expanded(
                child: AnimatedTankWidget(
                  label: 'LLUVIA',
                  level: state.rainTankLevel,
                  color: const Color(0xFF00B4D8),
                  icon: Icons.cloud_queue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedTankWidget(
                  label: 'CALLE',
                  level: state.streetTankLevel,
                  color: const Color(0xFF48CAE4),
                  icon: Icons.location_city,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Bridge Status Banner ──────────────────────────────────────────────────────

class _BridgeStatusBanner extends ConsumerWidget {
  const _BridgeStatusBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(bridgeHealthProvider);

    // ── Web mode: neutral grey info pill ─────────────────────────────
    if (health.status == BridgeStatus.webMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(80),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Modo Web — MQTT directo (bridge local no disponible)',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withAlpha(100),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
    }

    // ── Desktop: green (ok) or red (error) animated container ────────
    final isOk = health.status == BridgeStatus.ok;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOk
            ? const Color(0xFF00E676).withAlpha(14)
            : Colors.redAccent.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk
              ? const Color(0xFF00E676).withAlpha(50)
              : Colors.redAccent.withAlpha(60),
          width: 1,
        ),
      ),
      child: isOk
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Servicios de Fondo: ACTIVOS'
                  '${health.mqttStatus == "connected" ? "  •  MQTT ✓" : ""}'
                  '${health.dbStatus == "ready" ? "  •  DB ✓" : ""}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    health.errorMessage ??
                        "Bridge no detectado. Corre 'node index.js' en tu terminal",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Status Bar ────────────────────────────────────────────────────

class _ActuatorStatusBar extends StatelessWidget {
  final WaterSystemState state;
  const _ActuatorStatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final systemActive = state.isPumpActive && state.isSolenoidOpen;
    final systemLabel = systemActive
        ? 'SISTEMA ACTIVO'
        : state.isPumpActive
            ? 'PRESURIZADO'
            : 'EN ESPERA';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(14), width: 1),
        ),
        child: Row(
          children: [
            _LedPill(
              icon: Icons.power_settings_new,
              label: 'Bomba',
              isActive: state.isPumpActive,
              activeColor: const Color(0xFF00E676),
            ),
            const SizedBox(width: 10),
            _LedPill(
              icon: Icons.adjust,
              label: 'Solenoide',
              isActive: state.isSolenoidOpen,
              activeColor: const Color(0xFF00E5FF),
            ),
            const Spacer(),
            _SystemCapsule(isActive: systemActive, label: systemLabel),
          ],
        ),
      ),
    );
  }
}

// ── LED Pill ───────────────────────────────────────────────────────

class _LedPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;

  const _LedPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(isActive ? 55 : 25), width: 1),
        boxShadow: isActive
            ? [BoxShadow(color: color.withAlpha(35), blurRadius: 10)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [BoxShadow(color: color.withAlpha(150), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white.withAlpha(200) : Colors.white38,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(isActive ? 30 : 15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing system capsule ─────────────────────────────────────────

class _SystemCapsule extends StatefulWidget {
  final bool isActive;
  final String label;
  const _SystemCapsule({required this.isActive, required this.label});

  @override
  State<_SystemCapsule> createState() => _SystemCapsuleState();
}

class _SystemCapsuleState extends State<_SystemCapsule>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isActive ? const Color(0xFF00E676) : const Color(0xFF6B2323);
    final textColor = widget.isActive ? Colors.white : Colors.white54;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = widget.isActive ? _anim.value : 0.7;
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(widget.isActive ? 18 : 12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withAlpha(widget.isActive ? 60 : 30),
                width: 1,
              ),
              boxShadow: widget.isActive
                  ? [BoxShadow(color: color.withAlpha(30), blurRadius: 12)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: widget.isActive
                        ? [BoxShadow(color: color.withAlpha(160), blurRadius: 6)]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Hover-reveal navigation arrow ─────────────────────────────────

class _HoverArrow extends StatefulWidget {
  final Alignment alignment;
  final IconData icon;
  final VoidCallback onTap;

  const _HoverArrow({
    required this.alignment,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HoverArrow> createState() => _HoverArrowState();
}

class _HoverArrowState extends State<_HoverArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.alignment == Alignment.centerLeft;

    return Positioned.fill(
      child: Align(
        alignment: widget.alignment,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.25,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: Container(
                width: 44,
                height: 44,
                margin: EdgeInsets.only(
                  left: isLeft ? 10 : 0,
                  right: isLeft ? 0 : 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withAlpha(60),
                    width: 1,
                  ),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withAlpha(30),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: const Color(0xFF00E5FF)
                      .withAlpha(_hovered ? 230 : 140),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
