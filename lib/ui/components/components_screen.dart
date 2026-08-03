import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComponentsScreen — Gestión de Componentes del Sistema SIGA
// Muestra los componentes actuales y permite agregar nuevos.
// ─────────────────────────────────────────────────────────────────────────────

// ── Modelos de datos ──────────────────────────────────────────────────────────

enum ComponentType { fuente, salida, bomba }

class SigaComponent {
  final String id;
  final String nombre;
  final ComponentType tipo;
  final String topicBase;
  final bool tieneSensor;
  final bool esExistente; // true = ya instalado, false = nuevo/pendiente

  const SigaComponent({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.topicBase,
    this.tieneSensor = false,
    this.esExistente = true,
  });

  String get topicActuadorBomba   => 'agua_iot/actuadores/bomba_$topicBase';
  String get topicActuadorSolenoide => 'agua_iot/actuadores/solenoide_$topicBase';
  String get topicNivel           => 'agua_iot/tanque_$topicBase/nivel';
  String get topicHeartbeat       => 'agua_iot/heartbeat/control_$topicBase';

  IconData get icon {
    switch (tipo) {
      case ComponentType.fuente:  return Icons.water_drop_rounded;
      case ComponentType.salida:  return Icons.output_rounded;
      case ComponentType.bomba:   return Icons.settings_input_component_rounded;
    }
  }

  Color get color {
    switch (tipo) {
      case ComponentType.fuente:  return const Color(0xFF00E5FF);
      case ComponentType.salida:  return const Color(0xFF69FF47);
      case ComponentType.bomba:   return const Color(0xFFFF9100);
    }
  }

  String get tipoLabel {
    switch (tipo) {
      case ComponentType.fuente:  return 'FUENTE DE ENTRADA';
      case ComponentType.salida:  return 'SALIDA';
      case ComponentType.bomba:   return 'BOMBA PRINCIPAL';
    }
  }
}

// ── Componentes actuales del sistema ─────────────────────────────────────────

final _componentesProvider = StateProvider<List<SigaComponent>>((ref) => [
  const SigaComponent(
    id: 'calle',
    nombre: 'Fuente Red Pública (Calle)',
    tipo: ComponentType.fuente,
    topicBase: 'calle',
    tieneSensor: true,
    esExistente: true,
  ),
  const SigaComponent(
    id: 'lluvia',
    nombre: 'Fuente Agua de Lluvia',
    tipo: ComponentType.fuente,
    topicBase: 'lluvia',
    tieneSensor: true,
    esExistente: true,
  ),
  const SigaComponent(
    id: 'bomba',
    nombre: 'Bomba Principal',
    tipo: ComponentType.bomba,
    topicBase: 'bomba',
    tieneSensor: false,
    esExistente: true,
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────

class ComponentsScreen extends ConsumerWidget {
  const ComponentsScreen({super.key});

  static const _bg     = Color(0xFF0D0D1A);
  static const _accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final componentes = ref.watch(_componentesProvider);
    final systemState = ref.watch(processedSystemStateProvider);

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddComponentDialog(context, ref),
        backgroundColor: _accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Agregar componente',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _accent.withAlpha(50)),
                        ),
                        child: const Icon(Icons.device_hub_rounded,
                            color: _accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gestión del Sistema',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '${componentes.where((c) => c.esExistente).length} componentes activos',
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Info banner de escalabilidad
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _accent, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'El sistema SIGA está diseñado para escalar. '
                            'Puedes agregar nuevas fuentes de entrada o salidas '
                            'sin modificar los componentes existentes.',
                            style: TextStyle(
                              color: Colors.white.withAlpha(160),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sección: Componentes instalados ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'COMPONENTES INSTALADOS',
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final comp = componentes[i];
                  // Determinar estado online desde systemState
                  bool online = true;
                  if (comp.id == 'calle') {
                    online = systemState.esp32ControlOnline;
                  } else if (comp.id == 'lluvia') {
                    online = systemState.esp32ControlOnline;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ComponentCard(
                      component: comp,
                      online: online,
                      onTap: () => _showComponentDetail(context, comp),
                    ),
                  );
                },
                childCount: componentes.length,
              ),
            ),
          ),

          // ── Sección: Cómo añadir ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Text(
                'GUÍA DE INTEGRACIÓN',
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: _IntegrationGuideCard(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialog: Agregar nuevo componente ─────────────────────────────────────
  void _showAddComponentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _AddComponentDialog(
        onAdd: (comp) {
          ref.read(_componentesProvider.notifier).update(
                (list) => [...list, comp],
              );
        },
      ),
    );
  }

  void _showComponentDetail(BuildContext context, SigaComponent comp) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ComponentDetailSheet(component: comp),
    );
  }
}

// ── Tarjeta de componente ─────────────────────────────────────────────────────

class _ComponentCard extends StatelessWidget {
  final SigaComponent component;
  final bool online;
  final VoidCallback onTap;

  const _ComponentCard({
    required this.component,
    required this.online,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: component.esExistente
                  ? component.color.withAlpha(40)
                  : Colors.orange.withAlpha(40),
            ),
          ),
          child: Row(
            children: [
              // Icono
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: component.color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(component.icon, color: component.color, size: 22),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      component.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: component.color.withAlpha(15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            component.tipoLabel,
                            style: TextStyle(
                              color: component.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (component.tieneSensor) ...[ 
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SENSOR NIVEL',
                              style: TextStyle(
                                color: Colors.white.withAlpha(100),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'agua_iot/actuadores/...${component.topicBase}',
                      style: TextStyle(
                        color: Colors.white.withAlpha(60),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: component.esExistente && online
                              ? const Color(0xFF69FF47)
                              : component.esExistente
                                  ? Colors.orange
                                  : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        component.esExistente
                            ? (online ? 'Online' : 'Offline')
                            : 'Pendiente',
                        style: TextStyle(
                          color: Colors.white.withAlpha(100),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white.withAlpha(40), size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Guía de integración ───────────────────────────────────────────────────────

class _IntegrationGuideCard extends StatelessWidget {
  final _steps = const [
    _GuideStep(
      icon: Icons.settings_input_component_rounded,
      color: Color(0xFF00E5FF),
      title: 'Paso 1 — Hardware',
      description:
          'Conecta un nuevo Arduino Nano ESP32 con el relé de la bomba y/o solenoide. '
          'Si la fuente tiene tanque, agrega un sensor ultrasónico AJ-SR04M.',
    ),
    _GuideStep(
      icon: Icons.code_rounded,
      color: Color(0xFF69FF47),
      title: 'Paso 2 — Firmware ESP32',
      description:
          'Usa el código base de fuente (disponible en el repositorio). '
          'Cambia solo el nombre del tópico: bomba_pozo, solenoide_pozo, etc. '
          'El resto del código es idéntico.',
    ),
    _GuideStep(
      icon: Icons.add_circle_outline_rounded,
      color: Color(0xFFFF9100),
      title: 'Paso 3 — Registrar en SIGA',
      description:
          'Usa el botón "Agregar componente" en esta pantalla. '
          'El sistema genera automáticamente los tópicos MQTT y las instrucciones de integración.',
    ),
    _GuideStep(
      icon: Icons.cloud_upload_rounded,
      color: Color(0xFFE040FB),
      title: 'Paso 4 — Desplegar',
      description:
          'El backend detecta el nuevo ESP32 por su heartbeat y comienza a recibir datos. '
          'No se necesita reiniciar ningún servicio.',
    ),
  ];

  const _IntegrationGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cómo añadir una nueva fuente o salida',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El proceso toma aproximadamente 30 minutos incluyendo el hardware',
            style: TextStyle(
              color: Colors.white.withAlpha(80),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          ..._steps.map((s) => _StepTile(step: s)),
        ],
      ),
    );
  }
}

class _GuideStep {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _GuideStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

class _StepTile extends StatelessWidget {
  final _GuideStep step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: step.color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(step.icon, color: step.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: step.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.description,
                  style: TextStyle(
                    color: Colors.white.withAlpha(140),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog: Agregar componente ────────────────────────────────────────────────

class _AddComponentDialog extends StatefulWidget {
  final void Function(SigaComponent) onAdd;
  const _AddComponentDialog({required this.onAdd});

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  int _step = 0;
  final _nameCtrl  = TextEditingController();
  final _idCtrl    = TextEditingController();
  ComponentType _tipo = ComponentType.fuente;
  bool _tieneSensor = true;

  static const _bg     = Color(0xFF13131A);
  static const _accent = Color(0xFF00E5FF);

  String get _topicBase => _idCtrl.text.trim().toLowerCase().replaceAll(' ', '_');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _buildStep0() : _buildStep1(),
        ),
      ),
    );
  }

  // ── Paso 0: Información básica ──────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogHeader(
          title: 'Nuevo componente',
          subtitle: 'Paso 1 de 2 — Información básica',
        ),
        const SizedBox(height: 20),

        // Nombre
        _Label('Nombre del componente'),
        const SizedBox(height: 6),
        _TextField(
          controller: _nameCtrl,
          hint: 'Ej: Fuente Pozo, Salida Jardín',
        ),
        const SizedBox(height: 16),

        // ID / Topic base
        _Label('Identificador único (sin espacios)'),
        const SizedBox(height: 6),
        _TextField(
          controller: _idCtrl,
          hint: 'Ej: pozo, jardin, salida_2',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          ],
        ),
        const SizedBox(height: 16),

        // Tipo
        _Label('Tipo de componente'),
        const SizedBox(height: 8),
        Row(
          children: ComponentType.values.map((t) {
            final selected = _tipo == t;
            final color = selected ? _accent : Colors.white24;
            final labels = {
              ComponentType.fuente: 'Fuente',
              ComponentType.salida: 'Salida',
              ComponentType.bomba: 'Bomba',
            };
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _tipo = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? _accent.withAlpha(20) : Colors.white.withAlpha(5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withAlpha(selected ? 80 : 30)),
                    ),
                    child: Text(
                      labels[t]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? _accent : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ¿Tiene sensor?
        if (_tipo == ComponentType.fuente)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('¿Tiene tanque con sensor de nivel?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ChipToggle(
                    label: 'Sí, tiene sensor',
                    selected: _tieneSensor,
                    onTap: () => setState(() => _tieneSensor = true),
                  ),
                  const SizedBox(width: 8),
                  _ChipToggle(
                    label: 'Solo bomba/válvula',
                    selected: !_tieneSensor,
                    onTap: () => setState(() => _tieneSensor = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),

        // Botones
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: TextStyle(color: Colors.white.withAlpha(100))),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _nameCtrl.text.isNotEmpty && _idCtrl.text.isNotEmpty
                  ? () => setState(() => _step = 1)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Siguiente →',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Paso 1: Resumen + instrucciones ────────────────────────────────────────
  Widget _buildStep1() {
    final topics = <String>[];
    if (_tipo == ComponentType.fuente || _tipo == ComponentType.bomba) {
      topics.add('agua_iot/actuadores/bomba_$_topicBase');
      topics.add('agua_iot/actuadores/solenoide_$_topicBase');
      topics.add('agua_iot/heartbeat/control_$_topicBase');
    }
    if (_tipo == ComponentType.salida) {
      topics.add('agua_iot/actuadores/salida_$_topicBase');
      topics.add('agua_iot/heartbeat/control_$_topicBase');
    }
    if (_tieneSensor && _tipo == ComponentType.fuente) {
      topics.add('agua_iot/tanque_$_topicBase/nivel');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogHeader(
          title: _nameCtrl.text,
          subtitle: 'Paso 2 de 2 — Tópicos MQTT generados',
        ),
        const SizedBox(height: 16),

        // Topics generados
        ...topics.map((t) => _TopicChip(topic: t)),
        const SizedBox(height: 16),

        // Instrucciones hardware
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pasos de hardware requeridos:',
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _InstrStep('1', 'Flashear un Arduino Nano ESP32 con el código base de fuente del repositorio'),
              _InstrStep('2', 'Cambiar topicBase = "$_topicBase" en el código'),
              if (_tieneSensor && _tipo == ComponentType.fuente)
                _InstrStep('3', 'Conectar sensor AJ-SR04M a pines D2/D3 y calibrar VACIO/LLENO'),
              _InstrStep(
                _tieneSensor && _tipo == ComponentType.fuente ? '4' : '3',
                'Conectar relé al GPIO 26 (bomba) y GPIO 27 (solenoide)',
              ),
              _InstrStep(
                _tieneSensor && _tipo == ComponentType.fuente ? '5' : '4',
                'Encender el ESP32 — el backend lo detecta automáticamente por el heartbeat',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Botones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: Text('← Atrás',
                  style: TextStyle(color: Colors.white.withAlpha(100))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final nuevo = SigaComponent(
                  id: _topicBase,
                  nombre: _nameCtrl.text.trim(),
                  tipo: _tipo,
                  topicBase: _topicBase,
                  tieneSensor: _tieneSensor,
                  esExistente: false,
                );
                widget.onAdd(nuevo);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${_nameCtrl.text} añadido — completa la configuración de hardware'),
                    backgroundColor: const Color(0xFF00E5FF).withAlpha(220),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF69FF47),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Agregar al sistema',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Bottom Sheet: Detalle del componente ─────────────────────────────────────

class _ComponentDetailSheet extends StatelessWidget {
  final SigaComponent component;
  const _ComponentDetailSheet({required this.component});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(component.icon, color: component.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  component.nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Tópicos MQTT'),
          const SizedBox(height: 8),
          _TopicChip(topic: component.topicActuadorBomba),
          if (component.tipo == ComponentType.fuente)
            _TopicChip(topic: component.topicActuadorSolenoide),
          if (component.tieneSensor)
            _TopicChip(topic: component.topicNivel),
          _TopicChip(topic: component.topicHeartbeat),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Widgets utilitarios ───────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _DialogHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 12,
            )),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: Colors.white.withAlpha(140),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          color: Colors.white.withAlpha(80),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ));
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final List<TextInputFormatter>? inputFormatters;

  const _TextField({
    required this.controller,
    required this.hint,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withAlpha(60), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withAlpha(8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withAlpha(20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00E5FF).withAlpha(20)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF00E5FF).withAlpha(80)
                : Colors.white.withAlpha(20),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF00E5FF) : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String topic;
  const _TopicChip({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: topic));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tópico copiado'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(5),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tag_rounded,
                  size: 12, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  topic,
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Icon(Icons.copy_rounded,
                  size: 12, color: Colors.white.withAlpha(40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstrStep extends StatelessWidget {
  final String num;
  final String text;
  const _InstrStep(this.num, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withAlpha(140),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
