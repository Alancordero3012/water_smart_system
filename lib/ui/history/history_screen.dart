import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Consumo'),
        centerTitle: true,
      ),
      body: Padding(
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
                Text('Red Pública'),
                SizedBox(width: 16),
                Icon(Icons.circle, color: Colors.green, size: 12),
                SizedBox(width: 4),
                Text('Agua de Lluvia'),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text('0h');
                            case 6:
                              return const Text('6h');
                            case 12:
                              return const Text('12h');
                            case 18:
                              return const Text('18h');
                            case 24:
                              return const Text('24h');
                          }
                          return const Text('');
                        },
                        interval: 6,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}L');
                        },
                        interval: 10,
                        reservedSize: 40,
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
                  maxY: 50,
                  lineBarsData: [
                    // Line 1: Street Water (Blue)
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 5),
                        FlSpot(4, 5),
                        FlSpot(8, 10), // Morning peak (Street used)
                        FlSpot(12, 5),
                        FlSpot(16, 8),
                        FlSpot(20, 10),
                        FlSpot(24, 5),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withAlpha(25),
                      ),
                    ),
                    // Line 2: Rain Water (Green) - Showing higher usage (Savings!)
                    LineChartBarData(
                      spots: const [
                        FlSpot(0, 0),
                        FlSpot(4, 2),
                        FlSpot(8, 20), // Morning peak (Rain preferred)
                        FlSpot(12, 15),
                        FlSpot(16, 25), // Afternoon irrigation (Rain)
                        FlSpot(20, 15),
                        FlSpot(24, 5),
                      ],
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withAlpha(25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              color: Colors.green[50],
              child: const ListTile(
                leading: Icon(Icons.savings, color: Colors.green),
                title: Text('Ahorro Estimado'),
                subtitle: Text(
                  'Has ahorrado 85 Litros de agua potable hoy gracias a la recolección de lluvia.',
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
