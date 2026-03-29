import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/repositories/water_data_repository.dart';
import 'mqtt_service.dart';

/// Simulation Mode repository.
///
/// Delegates ALL data acquisition to [MqttWaterRepository], which connects
/// to HiveMQ Cloud and receives real telemetry published by `simulador.js`.
///
/// No random data is generated here. The "simulation" label only refers to
/// the fact that the data source is the software simulator (simulador.js)
/// rather than physical hardware — but the MQTT pipeline is identical.
class SimulationModeRepository implements WaterDataRepository {
  final WaterDataRepository _mqtt;

  SimulationModeRepository(this._mqtt);

  @override
  Stream<WaterSystemState> get stateStream => _mqtt.stateStream;

  @override
  Future<void> initialize() => _mqtt.initialize();

  @override
  void sendCommand(String command, String value) =>
      _mqtt.sendCommand(command, value);

  @override
  void dispose() => _mqtt.dispose();
}

/// Provider for the simulation-mode repository.
/// Wraps an [MqttWaterRepository] internally.
final simulationRepositoryProvider = Provider<WaterDataRepository>((ref) {
  final mqttRepo = MqttWaterRepository();
  final repo = SimulationModeRepository(mqttRepo);
  ref.onDispose(() => repo.dispose());
  return repo;
});
