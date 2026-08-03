import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'worldwide_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WORLD SYSTEM DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class WorldSystemDetailScreen extends StatefulWidget {
  final WorldSystem system;
  const WorldSystemDetailScreen({super.key, required this.system});

  @override
  State<WorldSystemDetailScreen> createState() =>
      _WorldSystemDetailScreenState();
}

class _WorldSystemDetailScreenState extends State<WorldSystemDetailScreen>
    with TickerProviderStateMixin {
  late final AnimationController _headerCtrl;
  late final AnimationController _cardsCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _cardsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.system;
    final tanks = s.components.where((c) => c.type == SigaCompType.tank).toList();
    final pumps = s.components.where((c) => c.type == SigaCompType.pump).toList();
    final solenoids = s.components.where((c) => c.type == SigaCompType.solenoid).toList();
    final sensors = s.components
        .where((c) => [
              SigaCompType.qualitySensor,
              SigaCompType.flowSensor,
              SigaCompType.pressureSensor,
            ].contains(c.type))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF0D0D1A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      s.accent.withAlpha(40),
                      const Color(0xFF080812),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: FadeTransition(
                      opacity: _headerCtrl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(s.flag,
                                  style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${s.city}, ${s.country}',
                                      style: TextStyle(
                                        color: s.accent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(online: s.online, pulse: _pulseCtrl),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.description,
                            style: TextStyle(
                              color: Colors.white.withAlpha(120),
                              fontSize: 11,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Stats bar ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.water_drop_rounded,
                    value: '${tanks.length}',
                    label: 'Tanques',
                    color: s.accent,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.settings_input_component_rounded,
                    value: '${pumps.length + solenoids.length}',
                    label: 'Actuadores',
                    color: s.accent,
                  ),
                  if (sensors.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.sensors_rounded,
                      value: '${sensors.length}',
                      label: 'Sensores',
                      color: s.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Tanks section ─────────────────────────────────────────────────
          if (tanks.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.water_drop_rounded,
                  label: 'Nivel de Tanques',
                  color: s.accent),
            ),

          if (tanks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _TankCard(
                    comp: tanks[i],
                    accent: s.accent,
                    animCtrl: _cardsCtrl,
                    delay: i * 0.12,
                  ),
                  childCount: tanks.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
              ),
            ),

          // ── Pumps + Solenoids ─────────────────────────────────────────────
          if (pumps.isNotEmpty || solenoids.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.settings_input_component_rounded,
                  label: 'Actuadores',
                  color: s.accent),
            ),

          if (pumps.isNotEmpty || solenoids.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final all = [...pumps, ...solenoids];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ActuatorCard(
                        comp: all[i],
                        accent: s.accent,
                        animCtrl: _cardsCtrl,
                        delay: (tanks.length + i) * 0.1,
                      ),
                    );
                  },
                  childCount: pumps.length + solenoids.length,
                ),
              ),
            ),

          // ── Sensors ───────────────────────────────────────────────────────
          if (sensors.isNotEmpty)
            SliverToBoxAdapter(
              child: _SectionLabel(
                  icon: Icons.sensors_rounded,
                  label: 'Sensores',
                  color: s.accent),
            ),

          if (sensors.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _SensorCard(
                    comp: sensors[i],
                    accent: s.accent,
                    animCtrl: _cardsCtrl,
                    delay: (tanks.length + pumps.length + solenoids.length + i) * 0.1,
                  ),
                  childCount: sensors.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENT CARDS
// ══════════════════════════════════════════════════════════════════════════════

class _TankCard extends StatelessWidget {
  final SigaComp comp;
  final Color accent;
  final AnimationController animCtrl;
  final double delay;

  const _TankCard({
    required this.comp,
    required this.accent,
    required this.animCtrl,
    required this.delay,
  });

  Color _levelColor(double v) {
    if (v > 60) return Colors.greenAccent;
    if (v > 30) return Colors.orange;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final end = (delay + 0.5).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: animCtrl,
      curve: Interval(delay, end, curve: Curves.easeOut),
    );
    final color = _levelColor(comp.value);

    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(35)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular progress
              AnimatedBuilder(
                animation: animCtrl,
                builder: (_, __) {
                  final progress = (comp.value / 100) *
                      CurvedAnimation(
                              parent: animCtrl,
                              curve: Interval(delay,
                                  (delay + 0.5).clamp(0.0, 1.0),
                                  curve: Curves.easeOut))
                          .value;
                  return SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withAlpha(10),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                        ),
                        Text(
                          '${comp.value.round()}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                comp.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                comp.value > 60
                    ? 'Nivel adecuado'
                    : comp.value > 30
                        ? 'Nivel bajo'
                        : 'Nivel crítico',
                style: TextStyle(
                  color: color.withAlpha(160),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActuatorCard extends StatelessWidget {
  final SigaComp comp;
  final Color accent;
  final AnimationController animCtrl;
  final double delay;

  const _ActuatorCard({
    required this.comp,
    required this.accent,
    required this.animCtrl,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
        parent: animCtrl,
        curve: Interval(delay, end, curve: Curves.easeOut));

    final isOn = comp.value > 0;
    final isSolenoid = comp.type == SigaCompType.solenoid;
    final color = isOn ? Colors.greenAccent : Colors.white38;
    final icon = isSolenoid
        ? (isOn ? Icons.check_circle_rounded : Icons.cancel_rounded)
        : (isOn ? Icons.power_settings_new_rounded : Icons.power_off_rounded);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.15, 0), end: Offset.zero)
            .animate(anim),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOn ? Colors.greenAccent.withAlpha(40) : Colors.white.withAlpha(10)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isOn ? Colors.greenAccent : Colors.white).withAlpha(12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  comp.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOn ? Colors.greenAccent : Colors.white38).withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOn ? 'ACTIVO' : 'INACTIVO',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final SigaComp comp;
  final Color accent;
  final AnimationController animCtrl;
  final double delay;

  const _SensorCard({
    required this.comp,
    required this.accent,
    required this.animCtrl,
    required this.delay,
  });

  IconData get _icon {
    switch (comp.type) {
      case SigaCompType.qualitySensor:
      return Icons.opacity_rounded;
      case SigaCompType.flowSensor:
        return Icons.water_rounded;
      case SigaCompType.pressureSensor:
        return Icons.speed_rounded;
      default:
        return Icons.sensors_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
        parent: animCtrl,
        curve: Interval(delay, end, curve: Curves.easeOut));

    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withAlpha(30)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, color: accent, size: 26),
              const SizedBox(height: 8),
              Text(
                '${comp.value} ${comp.unit}',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comp.name,
                style: TextStyle(
                  color: Colors.white.withAlpha(140),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final bool online;
  final AnimationController pulse;
  const _StatusChip({required this.online, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.greenAccent : Colors.orange;
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: color.withAlpha((60 + 40 * pulse.value).round())),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha((150 + 80 * pulse.value).round()),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withAlpha(80),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withAlpha(80), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
