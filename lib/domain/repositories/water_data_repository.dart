import 'dart:async';
import '../../domain/models/water_system_state.dart';

/// Contrato abstracto para fuentes de datos de telemetría en tiempo real.
/// Implementado por MqttService (producción) y MockWaterService (simulación).
abstract class WaterDataRepository {
  /// Stream de estado del sistema en tiempo real
  Stream<WaterSystemState> get stateStream;

  /// Inicializar la conexión a la fuente de datos
  Future<void> initialize();

  /// Enviar un comando al sistema (ej: encender bomba, cambiar fuente)
  void sendCommand(String command, String value);

  /// Liberar recursos (cerrar sockets, streams, timers)
  void dispose();
}
