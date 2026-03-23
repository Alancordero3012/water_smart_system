import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/sensor_reading.dart';
import '../../domain/repositories/history_repository.dart';

/// Implementación de [HistoryRepository] que consulta el endpoint HTTP
/// del bridge Node.js (/api/lecturas) para leer datos de Aiven MySQL.
class AivenHistoryRepository implements HistoryRepository {
  final String baseUrl;

  AivenHistoryRepository({this.baseUrl = 'http://localhost:3001'});

  @override
  Future<List<SensorReading>> getRecentReadings() async {
    // Bridge runs on localhost — unreachable from a web browser context.
    if (kIsWeb) {
      debugPrint('⚠️ Historia: API local no disponible en web.');
      return [];
    }
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/lecturas'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => SensorReading.fromJson(e)).toList();
      }

      debugPrint('❌ API respondió con status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('❌ Error consultando historial: $e');
      return [];
    }
  }

  @override
  Future<List<SensorReading>> getReadings({
    int? componentId,
    DateTime? from,
    DateTime? to,
  }) async {
    // Para esta implementación, obtenemos todo y filtramos en cliente.
    // En producción se añadirían query params al endpoint.
    final allReadings = await getRecentReadings();
    return allReadings.where((r) {
      if (componentId != null && r.componentId != componentId) return false;
      if (from != null && r.timestamp.isBefore(from)) return false;
      if (to != null && r.timestamp.isAfter(to)) return false;
      return true;
    }).toList();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return AivenHistoryRepository();
});
