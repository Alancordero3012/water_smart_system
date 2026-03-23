import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/repositories/water_data_repository.dart';

/// Simulador IoT local con lógica interconectada entre 5 tópicos:
/// 1. Niveles (Rain/Street tanks)
/// 2. Actuadores (Bomba/Solenoide)
/// 3. Presión (conectada al estado de la bomba)
/// 4. Flujo (0 si bomba OFF y solenoide CLOSED)
/// 5. Turbidez
class MockWaterRepository implements WaterDataRepository {
  final StreamController<WaterSystemState> _controller =
      StreamController.broadcast();
  Timer? _timer;
  final Random _rng = Random();
  WaterSystemState _state = const WaterSystemState(
    rainTankLevel: 65.0,
    streetTankLevel: 78.0,
    streetPressure: 35.0,
    isPumpActive: true,
    isSolenoidOpen: true,
    activeSource: 'lluvia',
  );

  @override
  Stream<WaterSystemState> get stateStream => _controller.stream;

  @override
  Future<void> initialize() async {
    _startSimulation();
  }

  void _startSimulation() {
    _timer?.cancel();
    // Emit initial state immediately
    _controller.add(_state);

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _state = _generateNextState();
      _controller.add(_state);
    });
  }

  WaterSystemState _generateNextState() {
    final pump = _state.isPumpActive;
    final solenoid = _state.isSolenoidOpen;

    // --- 1. NIVELES DE TANQUE (fluctuación gradual ±1.5%) ---
    // Si el flujo está activo, el tanque fuente baja y el otro puede subir
    final bool flowing = pump && solenoid;
    final double drainRate = flowing ? _rng.nextDouble() * 1.2 : 0;
    final double fillRate = flowing ? _rng.nextDouble() * 0.3 : 0;

    double newRainLevel = _state.rainTankLevel;
    double newStreetLevel = _state.streetTankLevel;

    if (_state.activeSource == 'lluvia') {
      newRainLevel -= drainRate; // Se usa lluvia → baja
      newStreetLevel += fillRate; // Calle se mantiene o sube un poco
    } else {
      newStreetLevel -= drainRate; // Se usa calle → baja
      newRainLevel += fillRate; // Lluvia se mantiene
    }

    // Añadir fluctuación natural ±0.5
    newRainLevel += (_rng.nextDouble() - 0.5);
    newStreetLevel += (_rng.nextDouble() - 0.5);
    newRainLevel = newRainLevel.clamp(0.0, 100.0);
    newStreetLevel = newStreetLevel.clamp(0.0, 100.0);

    // --- 2. PRESIÓN (conectada a la bomba) ---
    double newPressure;
    if (pump) {
      // Bomba activa: presión fluctúa 28-42 PSI
      newPressure = _state.streetPressure +
          (_rng.nextDouble() * 4 - 2);
      newPressure = newPressure.clamp(28.0, 42.0);
    } else {
      // Bomba apagada: presión baja gradualmente
      newPressure = _state.streetPressure - _rng.nextDouble() * 2;
      newPressure = newPressure.clamp(5.0, 15.0);
    }

    // --- 3. FLUJO (CRÍTICO: 0 si bomba OFF y solenoide CLOSED) ---
    double newFlow;
    if (pump && solenoid) {
      // Flujo normal: 5-12 L/min
      newFlow = 5.0 + _rng.nextDouble() * 7.0;
    } else if (pump && !solenoid) {
      // Bomba on pero solenoide cerrada: presión se acumula, sin flujo
      newFlow = 0.0;
    } else {
      // Bomba off: sin flujo
      newFlow = 0.0;
    }

    // --- 4. TURBIDEZ ---
    double newTurbidity;
    if (_rng.nextDouble() > 0.95) {
      // 5% chance de spike (alerta de calidad)
      newTurbidity = 55.0 + _rng.nextDouble() * 20;
    } else {
      newTurbidity = 1.0 + _rng.nextDouble() * 7.0;
    }

    return _state.copyWith(
      rainTankLevel: newRainLevel,
      streetTankLevel: newStreetLevel,
      streetPressure: newPressure,
      flowRate: newFlow,
      turbidity: newTurbidity,
    );
  }

  @override
  void sendCommand(String command, String value) {
    switch (command) {
      case 'pump':
        _state = _state.copyWith(isPumpActive: value == 'ON');
        _controller.add(_state);
        break;
      case 'solenoid':
        _state = _state.copyWith(isSolenoidOpen: value == 'OPEN');
        _controller.add(_state);
        break;
      case 'source':
        _state = _state.copyWith(activeSource: value);
        _controller.add(_state);
        break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

final mockRepositoryProvider = Provider<WaterDataRepository>((ref) {
  final repo = MockWaterRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
