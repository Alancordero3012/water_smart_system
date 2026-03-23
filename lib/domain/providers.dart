import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/water_system_state.dart';
import 'repositories/water_data_repository.dart';
import 'services/smart_rules_service.dart';
import '../data/services/mqtt_service.dart';
import '../data/services/mock_water_service.dart';

// Toggle para Modo Simulación
final useSimulationProvider = StateProvider<bool>(
  (ref) => true,
); // Default true para demo

// Provider del repositorio activo (interfaz abstracta)
final waterDataRepositoryProvider = Provider<WaterDataRepository>((ref) {
  final isSimulation = ref.watch(useSimulationProvider);
  return isSimulation
      ? ref.watch(mockRepositoryProvider)
      : ref.watch(mqttRepositoryProvider);
});

// Stream principal del sistema
final waterSystemStreamProvider = StreamProvider<WaterSystemState>((ref) {
  final repository = ref.watch(waterDataRepositoryProvider);
  repository.initialize();
  return repository.stateStream;
});

// Estado procesado (con reglas inteligentes aplicadas)
final processedSystemStateProvider = Provider<WaterSystemState>((ref) {
  final rawStateAsync = ref.watch(waterSystemStreamProvider);
  final rulesService = ref.read(smartRulesProvider);

  return rawStateAsync.when(
    data: (state) => rulesService.evaluateRules(state),
    loading: () => const WaterSystemState(),
    error: (_, __) => const WaterSystemState(),
  );
});

// Exponer el AsyncValue para que la UI pueda mostrar loading/error
final waterSystemAsyncProvider = Provider<AsyncValue<WaterSystemState>>((ref) {
  return ref.watch(waterSystemStreamProvider);
});

// --- Sparkline History (últimos 20 valores por métrica) ---

class SparklineHistory {
  static const int maxPoints = 20;
  final List<double> pressure = [];
  final List<double> flow = [];
  final List<double> turbidity = [];
  final List<double> rainLevel = [];
  final List<double> streetLevel = [];

  void push(WaterSystemState state) {
    _add(pressure, state.streetPressure);
    _add(flow, state.flowRate);
    _add(turbidity, state.turbidity);
    _add(rainLevel, state.rainTankLevel);
    _add(streetLevel, state.streetTankLevel);
  }

  void _add(List<double> list, double value) {
    list.add(value);
    if (list.length > maxPoints) list.removeAt(0);
  }
}

final sparklineHistoryProvider = StateProvider<SparklineHistory>((ref) {
  final history = SparklineHistory();

  // Auto-update when new state arrives
  ref.listen(processedSystemStateProvider, (prev, next) {
    history.push(next);
    // Force re-read by notifying
    ref.notifyListeners();
  });

  return history;
});
