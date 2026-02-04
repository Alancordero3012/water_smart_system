import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/water_system_state.dart';
import 'services/smart_rules_service.dart';
import '../data/services/mqtt_service.dart';
import '../data/services/mock_water_service.dart';

// Toggle for Simulation Mode
final useSimulationProvider = StateProvider<bool>(
  (ref) => true,
); // Default to True for demo

// Main System State Provider
final waterSystemStreamProvider = StreamProvider<WaterSystemState>((ref) {
  final isSimulation = ref.watch(useSimulationProvider);

  if (isSimulation) {
    final mockService = ref.watch(mockWaterServiceProvider);
    mockService.startSimulation();
    ref.onDispose(() => mockService.stopSimulation());
    return mockService.stateStream;
  } else {
    final mqttService = ref.watch(mqttServiceProvider);
    mqttService.initialize(); // Ensure connected
    return mqttService.stateStream;
  }
});

// Processed State Provider (with Rules applied)
final processedSystemStateProvider = Provider<WaterSystemState>((ref) {
  final rawStateAsync = ref.watch(waterSystemStreamProvider);
  final rulesService = ref.read(smartRulesProvider);

  return rawStateAsync.when(
    data: (state) => rulesService.evaluateRules(state),
    loading: () => const WaterSystemState(), // Initial empty state
    error: (_, __) => const WaterSystemState(), // Fallback
  );
});
