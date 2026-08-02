import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/sensor_reading.dart';
import '../../domain/repositories/history_repository.dart';

class ConsumoHoy {
  final String fecha;
  final double litrosLluvia;
  final double litrosCalle;
  final double totalLitros;
  final double eficienciaPct;
  final String horaPico;
  final int fallasHoy;
  final int muestras;

  const ConsumoHoy({
    required this.fecha,
    required this.litrosLluvia,
    required this.litrosCalle,
    required this.totalLitros,
    required this.eficienciaPct,
    required this.horaPico,
    required this.fallasHoy,
    required this.muestras,
  });

  factory ConsumoHoy.fromJson(Map<String, dynamic> j) => ConsumoHoy(
        fecha         : j['fecha']           as String? ?? '',
        litrosLluvia  : (j['litros_lluvia']  as num?)?.toDouble() ?? 0,
        litrosCalle   : (j['litros_calle']   as num?)?.toDouble() ?? 0,
        totalLitros   : (j['total_litros']   as num?)?.toDouble() ?? 0,
        eficienciaPct : (j['eficiencia_pct'] as num?)?.toDouble() ?? 0,
        horaPico      : j['hora_pico']        as String? ?? '--:--',
        fallasHoy     : (j['fallas_hoy']      as num?)?.toInt() ?? 0,
        muestras      : (j['muestras']        as num?)?.toInt() ?? 0,
      );

  static ConsumoHoy empty() => const ConsumoHoy(
        fecha: '--', litrosLluvia: 0, litrosCalle: 0, totalLitros: 0,
        eficienciaPct: 0, horaPico: '--:--', fallasHoy: 0, muestras: 0);
}

class ConsumoDelDia {
  final String fecha;
  final double litrosLluvia;
  final double litrosCalle;
  final double totalLitros;
  final double eficienciaPct;

  const ConsumoDelDia({
    required this.fecha,
    required this.litrosLluvia,
    required this.litrosCalle,
    required this.totalLitros,
    required this.eficienciaPct,
  });

  factory ConsumoDelDia.fromJson(Map<String, dynamic> j) => ConsumoDelDia(
        fecha         : j['fecha']           as String? ?? '',
        litrosLluvia  : (j['litros_lluvia']  as num?)?.toDouble() ?? 0,
        litrosCalle   : (j['litros_calle']   as num?)?.toDouble() ?? 0,
        totalLitros   : (j['total_litros']   as num?)?.toDouble() ?? 0,
        eficienciaPct : (j['eficiencia_pct'] as num?)?.toDouble() ?? 0,
      );
}

class AivenHistoryRepository implements HistoryRepository {
  final String baseUrl;
  AivenHistoryRepository({this.baseUrl = 'https://watersmart-backend.onrender.com'});

  @override
  Future<List<SensorReading>> getRecentReadings() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/lecturas'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => SensorReading.fromJson(e)).toList();
      }
      debugPrint('API status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error historial: $e');
      return [];
    }
  }

  Future<ConsumoHoy> getConsumoHoy({int capacidadLitros = 200}) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/consumo/hoy?capacidad=$capacidadLitros'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return ConsumoHoy.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error consumo/hoy: $e');
    }
    return ConsumoHoy.empty();
  }

  Future<List<ConsumoDelDia>> getConsumoHistorico({int dias = 7, int capacidadLitros = 200}) async {
    try {
      final url = '$baseUrl/api/consumo/historico?dias=$dias&capacidad=$capacidadLitros';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => ConsumoDelDia.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error consumo/historico: $e');
    }
    return [];
  }

  @override
  Future<List<SensorReading>> getReadings({int? componentId, DateTime? from, DateTime? to}) async {
    final all = await getRecentReadings();
    return all.where((r) {
      if (componentId != null && r.componentId != componentId) return false;
      if (from != null && r.timestamp.isBefore(from)) return false;
      if (to != null && r.timestamp.isAfter(to)) return false;
      return true;
    }).toList();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => AivenHistoryRepository());

final consumoHoyProvider = FutureProvider<ConsumoHoy>((ref) async {
  final repo = ref.read(historyRepositoryProvider) as AivenHistoryRepository;
  return repo.getConsumoHoy();
});

final consumoHistoricoProvider = FutureProvider<List<ConsumoDelDia>>((ref) async {
  final repo = ref.read(historyRepositoryProvider) as AivenHistoryRepository;
  return repo.getConsumoHistorico(dias: 7);
});
