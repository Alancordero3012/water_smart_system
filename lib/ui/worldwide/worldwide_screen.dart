import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'world_system_detail.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════

enum SigaCompType { tank, pump, solenoid, qualitySensor, flowSensor, pressureSensor }

class SigaComp {
  final String name;
  final SigaCompType type;
  final double value;
  final String unit;
  const SigaComp({
    required this.name,
    required this.type,
    required this.value,
    this.unit = '',
  });
}

class WorldSystem {
  final String id;
  final String name;
  final String city;
  final String country;
  final String flag;
  final double lat;
  final double lng;
  final bool online;
  final Color accent;
  final String description;
  final List<SigaComp> components;

  const WorldSystem({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.flag,
    required this.lat,
    required this.lng,
    required this.online,
    required this.accent,
    required this.description,
    required this.components,
  });

  int get tankCount =>
      components.where((c) => c.type == SigaCompType.tank).length;
  int get pumpCount =>
      components.where((c) => c.type == SigaCompType.pump).length;
  int get sensorCount => components
      .where((c) => [
            SigaCompType.qualitySensor,
            SigaCompType.flowSensor,
            SigaCompType.pressureSensor,
          ].contains(c.type))
      .length;

  double get avgLevel {
    final tanks =
        components.where((c) => c.type == SigaCompType.tank).toList();
    if (tanks.isEmpty) return 0;
    return tanks.map((t) => t.value).reduce((a, b) => a + b) / tanks.length;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DATOS DEMO
// ══════════════════════════════════════════════════════════════════════════════

final kWorldSystems = <WorldSystem>[
  WorldSystem(
    id: 'vzla_001',
    name: 'SIGA Residencial',
    city: 'Caracas',
    country: 'Venezuela',
    flag: '🇻🇪',
    lat: 10.5, lng: -66.9,
    online: true,
    accent: const Color(0xFF00E5FF),
    description: 'Sistema residencial con 2 fuentes de agua y bomba principal. '
        'Fuente de red pública + captación de agua de lluvia.',
    components: const [
      SigaComp(name: 'Tanque Calle',    type: SigaCompType.tank,  value: 72),
      SigaComp(name: 'Tanque Lluvia',   type: SigaCompType.tank,  value: 45),
      SigaComp(name: 'Bomba Principal', type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Bomba Calle',     type: SigaCompType.pump,  value: 0),
      SigaComp(name: 'Solenoide Calle', type: SigaCompType.solenoid, value: 0),
      SigaComp(name: 'Bomba Lluvia',    type: SigaCompType.pump,  value: 0),
      SigaComp(name: 'Solenoide Lluvia',type: SigaCompType.solenoid,value: 0),
    ],
  ),
  WorldSystem(
    id: 'bgd_001',
    name: 'SIGA Industrial',
    city: 'Dhaka',
    country: 'Bangladesh',
    flag: '🇧🇩',
    lat: 23.8, lng: 90.4,
    online: true,
    accent: const Color(0xFFFF6B35),
    description: '3 tanques de reserva para producción textil, '
        '3 salidas independientes y monitoreo de calidad de agua.',
    components: const [
      SigaComp(name: 'Tanque Principal',  type: SigaCompType.tank,  value: 88),
      SigaComp(name: 'Tanque Reserva A',  type: SigaCompType.tank,  value: 61),
      SigaComp(name: 'Tanque Reserva B',  type: SigaCompType.tank,  value: 34),
      SigaComp(name: 'Bomba Salida 1',    type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Bomba Salida 2',    type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Bomba Salida 3',    type: SigaCompType.pump,  value: 0),
      SigaComp(name: 'Turbidez',          type: SigaCompType.qualitySensor, value: 2.1, unit: 'NTU'),
      SigaComp(name: 'Flujo Total',       type: SigaCompType.flowSensor,    value: 12.4, unit: 'L/min'),
    ],
  ),
  WorldSystem(
    id: 'col_001',
    name: 'SIGA Multifamiliar',
    city: 'Medellín',
    country: 'Colombia',
    flag: '🇨🇴',
    lat: 6.2, lng: -75.6,
    online: true,
    accent: const Color(0xFF69FF47),
    description: 'Edificio residencial de 12 pisos con 2 fuentes de agua, '
        '2 salidas por torre y sensor de flujo por piso.',
    components: const [
      SigaComp(name: 'Tanque Bajo',     type: SigaCompType.tank,  value: 91),
      SigaComp(name: 'Tanque Alto',     type: SigaCompType.tank,  value: 55),
      SigaComp(name: 'Bomba Torre A',   type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Bomba Torre B',   type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Sensor Flujo A',  type: SigaCompType.flowSensor,    value: 8.7, unit: 'L/min'),
      SigaComp(name: 'Sensor Presión',  type: SigaCompType.pressureSensor, value: 42.3, unit: 'PSI'),
    ],
  ),
  WorldSystem(
    id: 'mex_001',
    name: 'SIGA Compacto',
    city: 'Monterrey',
    country: 'México',
    flag: '🇲🇽',
    lat: 25.7, lng: -100.3,
    online: false,
    accent: const Color(0xFFE040FB),
    description: 'Instalación básica para pequeño comercio. '
        '1 tanque, 1 bomba y control remoto.',
    components: const [
      SigaComp(name: 'Tanque Principal', type: SigaCompType.tank, value: 23),
      SigaComp(name: 'Bomba Comercial',  type: SigaCompType.pump, value: 0),
      SigaComp(name: 'Solenoide',        type: SigaCompType.solenoid, value: 0),
    ],
  ),
  WorldSystem(
    id: 'esp_001',
    name: 'SIGA Premium',
    city: 'Sevilla',
    country: 'España',
    flag: '🇪🇸',
    lat: 37.4, lng: -5.9,
    online: true,
    accent: const Color(0xFFFFD740),
    description: 'Villa privada con sistema completo: captación de agua de lluvia, '
        'depósito subterráneo, monitoreo de calidad y riego automático.',
    components: const [
      SigaComp(name: 'Cisterna Principal', type: SigaCompType.tank, value: 95),
      SigaComp(name: 'Tanque Lluvia',      type: SigaCompType.tank, value: 78),
      SigaComp(name: 'Bomba Principal',    type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Riego',        type: SigaCompType.pump, value: 0),
      SigaComp(name: 'Calidad Agua',       type: SigaCompType.qualitySensor,  value: 0.4, unit: 'NTU'),
      SigaComp(name: 'Flujo Riego',        type: SigaCompType.flowSensor,     value: 3.2, unit: 'L/min'),
      SigaComp(name: 'Presión Red',        type: SigaCompType.pressureSensor, value: 58.1, unit: 'PSI'),
    ],
  ),
  WorldSystem(
    id: 'ind_001',
    name: 'SIGA Industrial+',
    city: 'Mumbai',
    country: 'India',
    flag: '🇮🇳',
    lat: 19.1, lng: 72.9,
    online: true,
    accent: const Color(0xFFFF4081),
    description: 'Planta manufacturera con 4 tanques de proceso, '
        '5 salidas independientes y monitoreo continuo de calidad.',
    components: const [
      SigaComp(name: 'Tanque Proceso A',  type: SigaCompType.tank, value: 82),
      SigaComp(name: 'Tanque Proceso B',  type: SigaCompType.tank, value: 67),
      SigaComp(name: 'Tanque Enfriamiento',type: SigaCompType.tank,value: 90),
      SigaComp(name: 'Tanque Reserva',    type: SigaCompType.tank, value: 44),
      SigaComp(name: 'Bomba Proceso 1',   type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Proceso 2',   type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Proceso 3',   type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Aux 1',       type: SigaCompType.pump, value: 0),
      SigaComp(name: 'Bomba Aux 2',       type: SigaCompType.pump, value: 0),
      SigaComp(name: 'pH Agua',           type: SigaCompType.qualitySensor,  value: 7.2, unit: 'pH'),
      SigaComp(name: 'Turbidez',          type: SigaCompType.qualitySensor,  value: 0.8, unit: 'NTU'),
      SigaComp(name: 'Flujo Total',       type: SigaCompType.flowSensor,     value: 38.6, unit: 'L/min'),
      SigaComp(name: 'Presión Sistema',   type: SigaCompType.pressureSensor, value: 72.4, unit: 'PSI'),
    ],
  ),
  WorldSystem(
    id: 'chl_001',
    name: 'SIGA Agrícola',
    city: 'Santiago',
    country: 'Chile',
    flag: '🇨🇱',
    lat: -33.4, lng: -70.6,
    online: true,
    accent: const Color(0xFF00BCD4),
    description: 'Sistema de riego agrícola con 2 fuentes, '
        'monitoreo de presión y control de zona de riego.',
    components: const [
      SigaComp(name: 'Estanque Canal',    type: SigaCompType.tank, value: 76),
      SigaComp(name: 'Estanque Pozo',     type: SigaCompType.tank, value: 58),
      SigaComp(name: 'Bomba Canal',       type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Pozo',        type: SigaCompType.pump, value: 0),
      SigaComp(name: 'Zona Riego A',      type: SigaCompType.solenoid, value: 1),
      SigaComp(name: 'Zona Riego B',      type: SigaCompType.solenoid, value: 0),
      SigaComp(name: 'Zona Riego C',      type: SigaCompType.solenoid, value: 0),
      SigaComp(name: 'Presión Red',       type: SigaCompType.pressureSensor, value: 38.9, unit: 'PSI'),
    ],
  ),
  WorldSystem(
    id: 'per_001',
    name: 'SIGA Municipal',
    city: 'Lima',
    country: 'Perú',
    flag: '🇵🇪',
    lat: -12.0, lng: -77.0,
    online: true,
    accent: const Color(0xFFFFAB40),
    description: 'Gestión de agua potable para barrio de 200 familias. '
        '3 fuentes, distribución por sectores y alertas automáticas.',
    components: const [
      SigaComp(name: 'Reservorio Norte',  type: SigaCompType.tank, value: 69),
      SigaComp(name: 'Reservorio Sur',    type: SigaCompType.tank, value: 81),
      SigaComp(name: 'Tanque Elevado',    type: SigaCompType.tank, value: 52),
      SigaComp(name: 'Bomba Sector A',    type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Sector B',    type: SigaCompType.pump, value: 1),
      SigaComp(name: 'Bomba Emergencia',  type: SigaCompType.pump, value: 0),
      SigaComp(name: 'Cloro Residual',    type: SigaCompType.qualitySensor,  value: 0.6, unit: 'mg/L'),
      SigaComp(name: 'Caudal Total',      type: SigaCompType.flowSensor,     value: 24.1, unit: 'L/min'),
    ],
  ),
  WorldSystem(
    id: 'dom_001',
    name: 'SIGA Residencial',
    city: 'Santo Domingo',
    country: 'Rep. Dominicana',
    flag: '🇩🇴',
    lat: 18.5, lng: -69.9,
    online: true,
    accent: const Color(0xFF40C4FF),
    description: 'Sistema residencial en zona norte con 2 tanques y control de bomba principal.',
    components: const [
      SigaComp(name: 'Tanque Principal', type: SigaCompType.tank,  value: 63),
      SigaComp(name: 'Tanque Reserva',  type: SigaCompType.tank,  value: 29),
      SigaComp(name: 'Bomba Principal', type: SigaCompType.pump,  value: 1),
      SigaComp(name: 'Solenoide',       type: SigaCompType.solenoid, value: 1),
      SigaComp(name: 'Presión Red',     type: SigaCompType.pressureSensor, value: 44.8, unit: 'PSI'),
    ],
  ),
  WorldSystem(
    id: 'dom_002',
    name: 'SIGA Comercial',
    city: 'Santiago de los Cab.',
    country: 'Rep. Dominicana',
    flag: '🇩🇴',
    lat: 19.5, lng: -70.7,
    online: false,
    accent: const Color(0xFF80D8FF),
    description: 'Local comercial con 1 tanque elevado y bomba de distribución.',
    components: const [
      SigaComp(name: 'Tanque Elevado',  type: SigaCompType.tank,  value: 41),
      SigaComp(name: 'Bomba Comercial', type: SigaCompType.pump,  value: 0),
      SigaComp(name: 'Solenoide',       type: SigaCompType.solenoid, value: 0),
    ],
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════

class WorldwideScreen extends StatefulWidget {
  const WorldwideScreen({super.key});

  @override
  State<WorldwideScreen> createState() => _WorldwideScreenState();
}

enum _Phase { globe, transition, grid }

class _WorldwideScreenState extends State<WorldwideScreen>
    with TickerProviderStateMixin {
  // Globe rotation (infinite)
  late final AnimationController _rotCtrl;
  // Globe scale entrance + shrink exit
  late final AnimationController _globeCtrl;
  late final Animation<double> _globeScale;
  late final Animation<double> _globeOpacity;
  // Cards stagger
  late final AnimationController _gridCtrl;
  // Breathe pulse for dots
  late final AnimationController _breatheCtrl;

  _Phase _phase = _Phase.globe;
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();

    _rotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _globeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _globeScale = CurvedAnimation(parent: _globeCtrl, curve: Curves.easeOutBack);
    _globeOpacity = CurvedAnimation(parent: _globeCtrl, curve: Curves.easeIn);

    _gridCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Sequence
    _globeCtrl.forward();
    _phaseTimer = Timer(const Duration(milliseconds: 2800), _startTransition);
  }

  void _startTransition() {
    if (!mounted) return;
    setState(() => _phase = _Phase.transition);
    _globeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.grid);
      _gridCtrl.forward();
    });
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _globeCtrl.dispose();
    _breatheCtrl.dispose();
    _gridCtrl.dispose();
    _searchCtrl.dispose();
    _phaseTimer?.cancel();
    super.dispose();
  }

  List<WorldSystem> get _filtered {
    if (_query.isEmpty) return kWorldSystems;
    final q = _query.toLowerCase();
    return kWorldSystems
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            s.country.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      body: Stack(
        children: [
          // Stars background
          const _StarsBackground(),

          // Content
          if (_phase == _Phase.grid) _buildGrid(),

          // Globe overlay (phases: globe + transition)
          if (_phase != _Phase.grid)
            _buildGlobeOverlay(),
        ],
      ),
    );
  }

  // ── Globe overlay ──────────────────────────────────────────────────────────

  Widget _buildGlobeOverlay() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_globeScale, _rotCtrl, _breatheCtrl]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _globeOpacity,
            child: ScaleTransition(
              scale: _globeScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Globe
                  RepaintBoundary(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: CustomPaint(
                        painter: _GlobePainter(
                          rotation: _rotCtrl.value * 2 * math.pi,
                          breathe: _breatheCtrl.value,
                          systems: kWorldSystems,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Label
                  Text(
                    'SIGA WORLDWIDE',
                    style: TextStyle(
                      color: const Color(0xFF00E5FF),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF00E5FF).withAlpha(120),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${kWorldSystems.length} instalaciones activas en ${kWorldSystems.map((s) => s.country).toSet().length} países',
                    style: TextStyle(
                      color: Colors.white.withAlpha(120),
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Online dots legend
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LegendDot(color: Colors.greenAccent, label: 'Online'),
                      const SizedBox(width: 20),
                      _LegendDot(color: Colors.orange, label: 'Offline'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid of cards ──────────────────────────────────────────────────────────

  Widget _buildGrid() {
    final systems = _filtered;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _rotCtrl,
                builder: (_, __) => CustomPaint(
                  size: const Size(42, 42),
                  painter: _GlobePainter(
                    rotation: _rotCtrl.value * 2 * math.pi,
                    breathe: _breatheCtrl.value,
                    systems: kWorldSystems,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SIGA Worldwide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    '${systems.length} sistema${systems.length != 1 ? 's' : ''} encontrado${systems.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        color: Colors.white.withAlpha(80), fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              // Online badge
              _OnlineBadge(
                  count: kWorldSystems.where((s) => s.online).length),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),

        // Cards
        Expanded(
          child: AnimatedBuilder(
            animation: _gridCtrl,
            builder: (context, _) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.08,
                ),
                itemCount: systems.length,
                itemBuilder: (context, i) {
                  final delay = (i * 0.1).clamp(0.0, 0.9);
                  final end = (delay + 0.4).clamp(0.0, 1.0);
                  final interval = CurvedAnimation(
                    parent: _gridCtrl,
                    curve: Interval(delay, end, curve: Curves.easeOutBack),
                  );
                  return FadeTransition(
                    opacity: interval,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(interval),
                      child: _SystemCard(
                        system: systems[i],
                        onTap: () => _openDetail(systems[i]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDetail(WorldSystem system) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => WorldSystemDetailScreen(system: system),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GLOBE PAINTER
// ══════════════════════════════════════════════════════════════════════════════

class _GlobePainter extends CustomPainter {
  final double rotation;
  final double breathe;
  final List<WorldSystem> systems;

  const _GlobePainter({
    required this.rotation,
    required this.breathe,
    required this.systems,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.92;
    final center = Offset(cx, cy);

    // ── Outer glow ───────────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00E5FF).withAlpha(0),
            const Color(0xFF00E5FF).withAlpha(18),
            const Color(0xFF00E5FF).withAlpha(0),
          ],
          stops: const [0.6, 0.82, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 1.15)),
    );

    // ── Clipped globe interior ────────────────────────────────────────────────
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));

    // Background gradient
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: const [Color(0xFF1B3F6A), Color(0xFF071428)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Latitude lines
    for (final frac in [-0.64, -0.38, 0.0, 0.38, 0.64]) {
      final ly = cy + r * frac;
      final lr = math.sqrt((r * r) - (r * frac) * (r * frac));
      final opa = frac == 0.0 ? 50 : 25;
      final sw = frac == 0.0 ? 0.8 : 0.5;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, ly), width: lr * 2, height: lr * 0.3),
        linePaint
          ..color = const Color(0xFF00E5FF).withAlpha(opa)
          ..strokeWidth = sw,
      );
    }

    // Longitude lines (animated)
    for (int i = 0; i < 9; i++) {
      final angle = rotation + (i / 9) * math.pi;
      final cosA = math.cos(angle).abs();
      final w = r * 2 * cosA;
      if (w < 2) continue;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: w, height: r * 2),
        linePaint
          ..color = const Color(0xFF00E5FF).withAlpha((22 * cosA).round())
          ..strokeWidth = 0.5,
      );
    }

    // Atmosphere overlay
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, -0.5),
          colors: [Colors.transparent, const Color(0xFF001030).withAlpha(100)],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    canvas.restore();

    // ── Globe border ─────────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF00E5FF).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── System dots ───────────────────────────────────────────────────────────
    for (final sys in systems) {
      final lngRad = sys.lng * math.pi / 180 + rotation;
      final latRad = sys.lat * math.pi / 180;
      final depth = math.cos(latRad) * math.cos(lngRad);

      if (depth > -0.1) {
        final x = cx + r * math.cos(latRad) * math.sin(lngRad);
        final y = cy - r * math.sin(latRad);
        final alpha = ((depth + 0.1) / 1.1).clamp(0.0, 1.0);
        final color = sys.online ? Colors.greenAccent : Colors.orange;

        // Glow
        canvas.drawCircle(
          Offset(x, y),
          (5 + breathe * 3.5) * alpha,
          Paint()
            ..color = color.withAlpha((80 * alpha).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
        // Core
        canvas.drawCircle(
          Offset(x, y),
          3.2 * alpha,
          Paint()..color = color.withAlpha((230 * alpha).round()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter old) =>
      old.rotation != rotation || old.breathe != breathe;
}

// ══════════════════════════════════════════════════════════════════════════════
// SYSTEM CARD
// ══════════════════════════════════════════════════════════════════════════════

class _SystemCard extends StatefulWidget {
  final WorldSystem system;
  final VoidCallback onTap;
  const _SystemCard({required this.system, required this.onTap});

  @override
  State<_SystemCard> createState() => _SystemCardState();
}

class _SystemCardState extends State<_SystemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lvlCtrl;

  @override
  void initState() {
    super.initState();
    _lvlCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _lvlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.system;
    final tanks = s.components.where((c) => c.type == SigaCompType.tank).toList();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              s.accent.withAlpha(18),
              const Color(0xFF0D0D1A),
            ],
          ),
          border: Border.all(color: s.accent.withAlpha(50), width: 1),
          boxShadow: [
            BoxShadow(
              color: s.accent.withAlpha(20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              Row(
                children: [
                  Text(s.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.city,
                          style: TextStyle(
                            color: s.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          s.country,
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PulseDot(online: s.online),
                ],
              ),
              const SizedBox(height: 10),

              // ── System name ───────────────────────────────────────────────
              Text(
                s.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // ── Tank level bars ───────────────────────────────────────────
              ...tanks.take(2).map((tank) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                tank.name,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(130),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _lvlCtrl,
                              builder: (_, __) => Text(
                                '${(tank.value * _lvlCtrl.value).round()}%',
                                style: TextStyle(
                                  color: s.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: AnimatedBuilder(
                            animation: _lvlCtrl,
                            builder: (_, __) => LinearProgressIndicator(
                              value: (tank.value / 100) * _lvlCtrl.value,
                              backgroundColor: Colors.white.withAlpha(12),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(s.accent),
                              minHeight: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

              if (tanks.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '+${tanks.length - 2} tanque${tanks.length - 2 > 1 ? 's' : ''} más',
                    style: TextStyle(
                      color: s.accent.withAlpha(160),
                      fontSize: 10,
                    ),
                  ),
                ),

              const Spacer(),

              // ── Component summary ─────────────────────────────────────────
              const Divider(color: Colors.white10, height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _CompBadge(Icons.water_drop_outlined, s.tankCount, 'tanques', s.accent),
                  _CompBadge(Icons.settings_input_component_outlined, s.pumpCount, 'bombas', s.accent),
                  if (s.sensorCount > 0)
                    _CompBadge(Icons.sensors_outlined, s.sensorCount, 'sensores', s.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITARIOS
// ══════════════════════════════════════════════════════════════════════════════

class _PulseDot extends StatefulWidget {
  final bool online;
  const _PulseDot({required this.online});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.online ? Colors.greenAccent : Colors.orange;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha((180 + 70 * _ctrl.value).round()),
              boxShadow: widget.online
                  ? [
                      BoxShadow(
                        color: color.withAlpha((80 * _ctrl.value).round()),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            widget.online ? 'Online' : 'Offline',
            style: TextStyle(
              color: color.withAlpha(200),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;
  const _CompBadge(this.icon, this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color.withAlpha(180), size: 14),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 9),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre, ciudad o país...',
        hintStyle: TextStyle(color: Colors.white.withAlpha(50), fontSize: 13),
        prefixIcon:
            Icon(Icons.search_rounded, color: Colors.white.withAlpha(60), size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded,
                    color: Colors.white.withAlpha(60), size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white.withAlpha(8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
        ),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final int count;
  const _OnlineBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.greenAccent)),
          const SizedBox(width: 6),
          Text(
            '$count online',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(140), fontSize: 12)),
      ],
    );
  }
}

class _StarsBackground extends StatelessWidget {
  const _StarsBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _StarsPainter(),
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = Colors.white.withAlpha(80);
    for (int i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.3;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
