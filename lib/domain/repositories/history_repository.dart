import '../models/sensor_reading.dart';

/// Contrato abstracto para consultas de datos históricos.
/// Implementado por AivenHistoryRepository (lee del bridge HTTP API).
abstract class HistoryRepository {
  /// Obtener lecturas históricas de las últimas 24 horas
  Future<List<SensorReading>> getRecentReadings();

  /// Obtener lecturas filtradas por componente y rango de tiempo
  Future<List<SensorReading>> getReadings({
    int? componentId,
    DateTime? from,
    DateTime? to,
  });
}
