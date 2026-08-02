// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/weather_service.dart';
import '../../domain/providers.dart';
import '../../domain/auth_provider.dart';
import '../auth/create_user_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _reserveThreshold  = 20.0;
  String _priority          = 'rain';
  bool   _predictiveSaving  = false;
  double _tankCapacity      = 200.0;
  double _weatherLat        = 10.48;
  double _weatherLon        = -66.90;
  Map<String, bool> _enabledRules = {};
  bool _isLoading = true;

  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _tankController = TextEditingController();

  // Nombres legibles de cada regla
  static const Map<String, String> _ruleNames = {
    'sensor_inconsistente'    : 'Sensor inconsistente',
    'fuga_agua'               : 'Fuga de agua',
    'presion_alta'            : 'Presión crítica alta',
    'rotura_tuberia'          : 'Rotura de tubería',
    'presion_baja'            : 'Presión baja → Failover',
    'restaurar_fuente'        : 'Restaurar fuente prioritaria',
    'tendencia_presion'       : 'Tendencia de presión (dP/dt)',
    'correlacion_nivel_flujo' : 'Correlación nivel↔flujo',
  };

  static const Map<String, String> _ruleIcons = {
    'sensor_inconsistente'    : '🔧',
    'fuga_agua'               : '💧',
    'presion_alta'            : '⚠️',
    'rotura_tuberia'          : '⛔',
    'presion_baja'            : '📉',
    'restaurar_fuente'        : 'ℹ️',
    'tendencia_presion'       : '⚡',
    'correlacion_nivel_flujo' : '📊',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _tankController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    setState(() {
      _reserveThreshold = prefs.minReserveThreshold;
      _priority         = prefs.prioritySource;
      _predictiveSaving = prefs.isPredictiveSavingEnabled;
      _tankCapacity     = prefs.tankCapacityLiters;
      _weatherLat       = prefs.weatherLatitude;
      _weatherLon       = prefs.weatherLongitude;
      _enabledRules     = prefs.enabledRulesMap;
      _latController.text  = _weatherLat.toStringAsFixed(4);
      _lonController.text  = _weatherLon.toStringAsFixed(4);
      _tankController.text = _tankCapacity.toStringAsFixed(0);
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setMinReserveThreshold(_reserveThreshold);
    await prefs.setPrioritySource(_priority);
    await prefs.setPredictiveSaving(_predictiveSaving);
    await prefs.setTankCapacityLiters(double.tryParse(_tankController.text) ?? _tankCapacity);
    await prefs.setWeatherCoordinates(
      double.tryParse(_latController.text) ?? _weatherLat,
      double.tryParse(_lonController.text) ?? _weatherLon,
    );
    await prefs.saveEnabledRules(_enabledRules);

    // Invalidar caché del clima si cambiaron coordenadas
    ref.read(weatherServiceProvider).invalidateCache();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              SizedBox(width: 10),
              Text('Configuración guardada'),
            ],
          ),
          backgroundColor: Color(0xFF1A1A2E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isSimulation = ref.watch(useSimulationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [

          // ══════════════════════════════════════════════════════════
          // SISTEMA
          // ══════════════════════════════════════════════════════════
          _sectionLabel('SISTEMA'),
          const SizedBox(height: 8),

          // ── Gestión de usuarios (solo admin) ─────────────────────────────────────
          if (ref.watch(authProvider).user?.isAdmin == true) ...[
            _card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add_rounded,
                      color: Color(0xFF00E5FF), size: 20),
                ),
                title: const Text('Gestión de usuarios',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Crear cuentas de operador u observador',
                  style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white30, size: 14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateUserScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          _card(
            border: isSimulation
                ? Colors.orange.withAlpha(60)
                : const Color(0xFF00E5FF).withAlpha(40),
            child: SwitchListTile(
              title: const Text('Modo Simulación'),
              subtitle: Text(
                isSimulation
                    ? 'Usando datos simulados localmente'
                    : 'Conectado a broker MQTT en vivo',
                style: TextStyle(
                  color: isSimulation ? Colors.orange : Colors.cyanAccent,
                  fontSize: 12,
                ),
              ),
              secondary: Icon(
                isSimulation ? Icons.science : Icons.sensors,
                color: isSimulation ? Colors.orange : Colors.cyanAccent,
              ),
              value: isSimulation,
              activeThumbColor: Colors.orange,
              onChanged: (value) {
                ref.read(useSimulationProvider.notifier).state = value;
              },
            ),
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // TANQUE — capacidad real (para cálculo de litros)
          // ══════════════════════════════════════════════════════════
          _sectionLabel('TANQUE'),
          const SizedBox(height: 8),
          _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.water, color: Color(0xFF00B4D8), size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Capacidad del Tanque',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Usado para calcular litros de ahorro real',
                            style: TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _tankController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                      decoration: const InputDecoration(
                        suffixText: 'L',
                        suffixStyle: TextStyle(color: Colors.white38, fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // REGLAS INTELIGENTES — umbrales + reserva
          // ══════════════════════════════════════════════════════════
          _sectionLabel('REGLAS INTELIGENTES'),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Reserva Mínima de Emergencia'),
            subtitle: Text('${_reserveThreshold.toInt()}%'),
            leading: const Icon(Icons.shield),
          ),
          Slider(
            value: _reserveThreshold,
            min: 5.0,
            max: 50.0,
            divisions: 9,
            label: '${_reserveThreshold.toInt()}%',
            onChanged: (value) => setState(() => _reserveThreshold = value),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Si el nivel de lluvia cae por debajo de este valor, '
              'se cambiará automáticamente a la red pública.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // REGLAS ACTIVAS — toggle individual por regla
          // ══════════════════════════════════════════════════════════
          _sectionLabel('REGLAS ACTIVAS'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Desactiva reglas individuales si un sensor está desconectado temporalmente.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ),
          _card(
            child: Column(
              children: kAllSmartRules.map((ruleKey) {
                final isFirst = kAllSmartRules.first == ruleKey;
                return Column(
                  children: [
                    if (!isFirst)
                      Divider(height: 1, color: Colors.white.withAlpha(8)),
                    SwitchListTile(
                      dense: true,
                      title: Text(
                        '${_ruleIcons[ruleKey] ?? '🔹'} ${_ruleNames[ruleKey] ?? ruleKey}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: _enabledRules[ruleKey] ?? true,
                      activeTrackColor: const Color(0xFF00E5FF),
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        setState(() => _enabledRules[ruleKey] = val);
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // PRIORIDADES
          // ══════════════════════════════════════════════════════════
          _sectionLabel('PRIORIDADES'),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('Priorizar Lluvia'),
            subtitle: const Text('Ahorrar agua de la red siempre que sea posible.'),
            value: 'rain',
            groupValue: _priority,
            onChanged: (value) => setState(() => _priority = value!),
          ),
          RadioListTile<String>(
            title: const Text('Priorizar Red Pública'),
            subtitle: const Text('Usar lluvia solo como respaldo.'),
            value: 'street',
            groupValue: _priority,
            onChanged: (value) => setState(() => _priority = value!),
          ),

          const SizedBox(height: 24),

          // ══════════════════════════════════════════════════════════
          // AHORRO INTELIGENTE — clima predictivo (ahora funciona)
          // ══════════════════════════════════════════════════════════
          _sectionLabel('AHORRO INTELIGENTE'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Ahorro Predictivo (Clima)'),
                  subtitle: const Text(
                    'Recomienda conservar agua de lluvia si hay pronóstico '
                    'de precipitación en 12h.',
                  ),
                  secondary: const Icon(Icons.cloud_sync, color: Colors.blue),
                  value: _predictiveSaving,
                  onChanged: (value) {
                    setState(() => _predictiveSaving = value);
                    if (value) ref.invalidate(weatherForecastProvider);
                  },
                ),
                if (_predictiveSaving) ...[
                  Divider(height: 1, color: Colors.white.withAlpha(8)),
                  const _WeatherForecastTile(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ══════════════════════════════════════════════════════════
          // COORDENADAS GPS (para Open-Meteo)
          // ══════════════════════════════════════════════════════════
          _card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 16),
                      const SizedBox(width: 8),
                      const Text('Ubicación para pronóstico',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Coordenadas GPS de tu instalación',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Latitud',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lonController,
                          keyboardType: const TextInputType.numberWithOptions(
                              signed: true, decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Longitud',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Guardar Cambios'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            label: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? border}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: border ?? Colors.white.withAlpha(12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withAlpha(100),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: Colors.white.withAlpha(15)),
        ),
      ],
    );
  }
}

// ── Widget de pronóstico de clima ─────────────────────────────────────────────

class _WeatherForecastTile extends ConsumerWidget {
  const _WeatherForecastTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(weatherForecastProvider);

    return forecastAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Consultando Open-Meteo...',
                  style: TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 16, color: Colors.white38),
            const SizedBox(width: 8),
            const Text('Sin conexión al servicio de clima',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
            const Spacer(),
            TextButton(
              onPressed: () => ref.invalidate(weatherForecastProvider),
              child: const Text('Reintentar', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
      data: (forecast) {
        final prob    = forecast.maxRainProbabilityNext12h;
        final isHigh  = forecast.rainLikely;
        final color   = isHigh ? Colors.blue : Colors.white54;
        final icon    = isHigh ? Icons.grain : Icons.wb_sunny_outlined;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHigh
                          ? '🌧️ Alta prob. de lluvia — conservar agua de tanque'
                          : '☀️ Poca lluvia esperada — uso normal',
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Prob. máx. próx. 12h: ${prob.toStringAsFixed(0)}%  '
                      '· Actualizado: ${_formatTime(forecast.fetchedAt)}',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white38),
                onPressed: () => ref.invalidate(weatherForecastProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}