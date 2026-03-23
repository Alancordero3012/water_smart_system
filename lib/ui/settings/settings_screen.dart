import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/preferences_service.dart';
import '../../domain/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _reserveThreshold = 20.0;
  String _priority = 'rain';
  bool _predictiveSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    setState(() {
      _reserveThreshold = prefs.minReserveThreshold;
      _priority = prefs.prioritySource;
      _predictiveSaving = prefs.isPredictiveSavingEnabled;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setMinReserveThreshold(_reserveThreshold);
    await prefs.setPrioritySource(_priority);
    await prefs.setPredictiveSaving(_predictiveSaving);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
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
          // === SIMULATION TOGGLE ===
          _sectionLabel('SISTEMA'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSimulation
                    ? Colors.orange.withAlpha(60)
                    : const Color(0xFF00E5FF).withAlpha(40),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
          ),

          const SizedBox(height: 24),

          // === SMART RULES ===
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
            onChanged: (value) {
              setState(() => _reserveThreshold = value);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Si el nivel de lluvia cae por debajo de este valor, se cambiará automáticamente a la red pública.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          const SizedBox(height: 24),

          // === PRIORITIES ===
          _sectionLabel('PRIORIDADES'),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('Priorizar Lluvia'),
            subtitle:
                const Text('Ahorrar agua de la red siempre que sea posible.'),
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

          // === PREDICTIVE ===
          _sectionLabel('AHORRO INTELIGENTE'),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Ahorro Predictivo (Clima)'),
            subtitle: const Text(
                'Posponer Riego si hay pronóstico de lluvia en 24h.'),
            secondary: const Icon(Icons.cloud_sync, color: Colors.blue),
            value: _predictiveSaving,
            onChanged: (value) => setState(() => _predictiveSaving = value),
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
        ],
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
