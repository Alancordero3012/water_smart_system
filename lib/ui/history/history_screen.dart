import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/aiven_history_repository.dart';
import '../../domain/models/sensor_reading.dart';
import '../shared/glass_container.dart';

/// Provider que carga lecturas históricas del bridge API
final historyDataProvider = FutureProvider<List<SensorReading>>((ref) async {
  final repo = ref.read(historyRepositoryProvider);
  return repo.getRecentReadings();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Consumo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyDataProvider),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorView(error, ref),
        data: (readings) => _buildContent(context, readings),
      ),
    );
  }

  Widget _buildErrorView(Object error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'No se pudo conectar con el servidor de datos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Asegúrate de que el bridge esté corriendo\n(npm start en backend_iot)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(historyDataProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<SensorReading> readings) {
    // Separar lecturas por componente
    final pressureReadings =
        readings.where((r) => r.componentId == 1).toList();
    final rainLevelReadings =
        readings.where((r) => r.componentId == 3).toList();
    final streetLevelReadings =
        readings.where((r) => r.componentId == 4).toList();

    // Calcular ahorro estimado a partir de lecturas de nivel de lluvia
    final savedLiters = rainLevelReadings.isNotEmpty
        ? (rainLevelReadings
                .map((r) => r.value)
                .reduce((a, b) => a + b) /
            rainLevelReadings.length *
            3.5) // Estimación simple
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Consumo Comparativo (Últimas 24 Horas)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Colors.blue, size: 12),
              SizedBox(width: 4),
              Text('Presión Red', style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, color: Colors.green, size: 12),
              SizedBox(width: 4),
              Text('Nivel Lluvia', style: TextStyle(fontSize: 12)),
              SizedBox(width: 16),
              Icon(Icons.circle, color: Colors.orange, size: 12),
              SizedBox(width: 4),
              Text('Nivel Calle', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: readings.isEmpty
                ? const Center(
                    child: Text(
                      'No hay datos disponibles.\nCorre el simulador y el bridge para generar lecturas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white10,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}h',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white54),
                              );
                            },
                            interval: 6,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white54),
                              );
                            },
                            interval: 20,
                            reservedSize: 35,
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 24,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        _buildLine(pressureReadings, Colors.blue, 2),
                        _buildLine(rainLevelReadings, Colors.green, 3),
                        _buildLine(streetLevelReadings, Colors.orange, 3),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.savings, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ahorro Estimado',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        readings.isEmpty
                            ? 'Sin datos aún'
                            : '~${savedLiters.toStringAsFixed(0)} Litros de lluvia usados',
                        style:
                            const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${readings.length}',
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'lecturas',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Convierte lecturas de un componente en puntos del chart
  LineChartBarData _buildLine(
      List<SensorReading> readings, Color color, double width) {
    // Agrupar por hora relativa (0-24)
    final now = DateTime.now();
    final spots = readings.map((r) {
      final hoursAgo = now.difference(r.timestamp).inMinutes / 60.0;
      final hourOnChart = 24.0 - hoursAgo;
      return FlSpot(hourOnChart.clamp(0, 24), r.value.clamp(0, 100));
    }).toList();

    // Si no hay datos, retornar línea vacía
    if (spots.isEmpty) {
      return LineChartBarData(spots: const [], show: false);
    }

    // Ordenar por X
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(20),
      ),
    );
  }
}
