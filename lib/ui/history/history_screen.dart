// ignore_for_file: deprecated_member_use
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/aiven_history_repository.dart';
import '../../data/services/preferences_service.dart';
import '../../domain/models/sensor_reading.dart';
import '../shared/glass_container.dart';

final historyDataProvider = FutureProvider<List<SensorReading>>((ref) async {
  final repo = ref.read(historyRepositoryProvider);
  return repo.getRecentReadings();
});

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(historyDataProvider);
    ref.invalidate(consumoHoyProvider);
    ref.invalidate(consumoHistoricoProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Consumo'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart, size: 18), text: 'En Vivo'),
            Tab(icon: Icon(Icons.bar_chart, size: 18),  text: '7 Días'),
            Tab(icon: Icon(Icons.savings, size: 18),    text: 'Ahorro'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TabEnVivo(),
          _TabSieteDias(),
          _TabAhorro(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — GRÁFICA EN VIVO (últimas 24h)
// ══════════════════════════════════════════════════════════════════════════════

class _TabEnVivo extends ConsumerWidget {
  const _TabEnVivo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyDataProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(historyDataProvider),
      ),
      data: (readings) => _buildLive(context, readings),
    );
  }

  Widget _buildLive(BuildContext context, List<SensorReading> readings) {
    final pressureR = readings.where((r) => r.componentId == 1).toList();
    final rainR     = readings.where((r) => r.componentId == 3).toList();
    final streetR   = readings.where((r) => r.componentId == 4).toList();

    final ref2 = ProviderScope.containerOf(context);
    final cap  = ref2.read(preferencesServiceProvider).tankCapacityLiters;

    double savedLiters = 0;
    if (rainR.length >= 2) {
      final sorted = [...rainR]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final delta = (sorted.first.value - sorted.last.value).clamp(0.0, 100.0);
      savedLiters = delta * cap / 100.0;
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Colors.blue,   label: 'Presión Red'),
              SizedBox(width: 16),
              _Legend(color: Color(0xFF00E5FF), label: 'Nivel Lluvia'),
              SizedBox(width: 16),
              _Legend(color: Colors.orange, label: 'Nivel Calle'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: readings.isEmpty
                ? const _EmptyChart()
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) =>
                            FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 6,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}h',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            interval: 20,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}',
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ),
                        ),
                        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0, maxX: 24, minY: 0, maxY: 100,
                      lineBarsData: [
                        _line(pressureR, Colors.blue,              2),
                        _line(rainR,     const Color(0xFF00E5FF),  3),
                        _line(streetR,   Colors.orange,            3),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          GlassContainer(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.savings, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agua de Lluvia Usada (24h)',
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        readings.length < 2
                            ? 'Sin datos suficientes aún'
                            : '${savedLiters.toStringAsFixed(1)} L  (Δnivel × ${cap.toStringAsFixed(0)} L tanque)',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${readings.length}',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 20)),
                    const Text('lecturas', style: TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<SensorReading> readings, Color color, double width) {
    final now   = DateTime.now();
    final spots = readings.map((r) {
      final hoursAgo  = now.difference(r.timestamp).inMinutes / 60.0;
      final x = (24.0 - hoursAgo).clamp(0.0, 24.0);
      return FlSpot(x, r.value.clamp(0, 100));
    }).toList();
    if (spots.isEmpty) return LineChartBarData(spots: const [], show: false);
    spots.sort((a, b) => a.x.compareTo(b.x));
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(20)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — GRÁFICA DE BARRAS 7 DÍAS
// ══════════════════════════════════════════════════════════════════════════════

class _TabSieteDias extends ConsumerWidget {
  const _TabSieteDias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(consumoHistoricoProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(consumoHistoricoProvider),
      ),
      data: (dias) => _buildWeek(dias),
    );
  }

  Widget _buildWeek(List<ConsumoDelDia> dias) {
    if (dias.isEmpty || dias.every((d) => d.totalLitros == 0)) {
      return const _EmptyChart(
        mensaje: 'Sin datos suficientes aún.\nNecesitas lecturas de al menos 2 días.',
      );
    }

    final maxY = dias.map((d) => d.totalLitros).reduce((a, b) => a > b ? a : b);
    final cap  = maxY > 0 ? maxY * 1.3 : 100.0;

    final totalLluvia = dias.fold(0.0, (s, d) => s + d.litrosLluvia);
    final totalCalle  = dias.fold(0.0, (s, d) => s + d.litrosCalle);
    final total       = totalLluvia + totalCalle;
    final efic        = total > 0 ? (totalLluvia / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Color(0xFF00B4D8), label: 'Lluvia'),
              SizedBox(width: 20),
              _Legend(color: Color(0xFF48CAE4), label: 'Calle (red pública)'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: cap,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final d = dias[group.x];
                      final label = ri == 0
                          ? '💧 Lluvia: ${d.litrosLluvia.toStringAsFixed(1)} L'
                          : '🏙️ Calle:  ${d.litrosCalle.toStringAsFixed(1)} L';
                      return BarTooltipItem(
                        label,
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= dias.length) return const SizedBox.shrink();
                        final parts = dias[i].fecha.split('-');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            parts.length == 3 ? '${parts[2]}/${parts[1]}' : dias[i].fecha,
                            style: const TextStyle(fontSize: 9, color: Colors.white38),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}L',
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                    ),
                  ),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(dias.length, (i) {
                  final d = dias[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.litrosLluvia,
                        color: const Color(0xFF00B4D8),
                        width: 10,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: d.litrosCalle,
                        color: const Color(0xFF48CAE4).withAlpha(160),
                        width: 10,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: 'Total lluvia', value: '${totalLluvia.toStringAsFixed(0)} L', color: const Color(0xFF00B4D8)),
              const SizedBox(width: 8),
              _StatChip(label: 'Total calle',  value: '${totalCalle.toStringAsFixed(0)} L',  color: const Color(0xFF48CAE4)),
              const SizedBox(width: 8),
              _StatChip(label: 'Eficiencia',   value: '${efic.toStringAsFixed(1)}%',         color: Colors.greenAccent),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — PANEL DE AHORRO DEL DÍA
// ══════════════════════════════════════════════════════════════════════════════

class _TabAhorro extends ConsumerWidget {
  const _TabAhorro();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(consumoHoyProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(consumoHoyProvider),
      ),
      data: (c) => _buildAhorro(c),
    );
  }

  Widget _buildAhorro(ConsumoHoy c) {
    final total      = c.totalLitros;
    final eficiencia = c.eficienciaPct;
    final barWidth   = total > 0 ? (c.litrosLluvia / total).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado de fecha ──────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                'Hoy · ${c.fecha}',
                style: const TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: eficiencia >= 50
                      ? Colors.green.withAlpha(25)
                      : Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: eficiencia >= 50
                        ? Colors.greenAccent.withAlpha(80)
                        : Colors.orange.withAlpha(80),
                  ),
                ),
                child: Text(
                  eficiencia >= 50 ? '✅ Buen ahorro' : '⚠️ Poco ahorro',
                  style: TextStyle(
                    fontSize: 11,
                    color: eficiencia >= 50 ? Colors.greenAccent : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Barra de eficiencia ──────────────────────────────────────────
          _sectionLabel('EFICIENCIA DE FUENTES'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('💧 Lluvia', style: TextStyle(fontSize: 13, color: Color(0xFF00B4D8))),
                    Text('🏙️ Calle', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(120))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: barWidth,
                    minHeight: 14,
                    backgroundColor: const Color(0xFF48CAE4).withAlpha(60),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${eficiencia.toStringAsFixed(1)}% lluvia',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF00B4D8), fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${(100 - eficiencia).toStringAsFixed(1)}% calle',
                      style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(100)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tarjetas de volumen ──────────────────────────────────────────
          _sectionLabel('VOLUMEN CONSUMIDO HOY'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _VolumeCard(
                  icon: Icons.cloud_queue,
                  label: 'Agua de Lluvia',
                  litros: c.litrosLluvia,
                  color: const Color(0xFF00B4D8),
                  sublabel: 'Gratuita / Sostenible',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _VolumeCard(
                  icon: Icons.location_city,
                  label: 'Red Pública',
                  litros: c.litrosCalle,
                  color: const Color(0xFF48CAE4),
                  sublabel: 'Pagada / Red municipal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Métricas del período ─────────────────────────────────────────
          _sectionLabel('MÉTRICAS DEL DÍA'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Column(
              children: [
                _MetricRow(
                  icon: Icons.water_drop,
                  label: 'Total consumido',
                  value: '${total.toStringAsFixed(1)} L',
                  color: Colors.cyanAccent,
                ),
                const Divider(color: Colors.white10, height: 16),
                _MetricRow(
                  icon: Icons.schedule,
                  label: 'Hora pico de consumo',
                  value: c.horaPico,
                  color: Colors.orange,
                ),
                const Divider(color: Colors.white10, height: 16),
                _MetricRow(
                  icon: Icons.sensors,
                  label: 'Lecturas procesadas',
                  value: '${c.muestras}',
                  color: Colors.white70,
                ),
                const Divider(color: Colors.white10, height: 16),
                _MetricRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Eventos de alerta (24h)',
                  value: '${c.fallasHoy}',
                  color: c.fallasHoy > 0 ? Colors.orange : Colors.greenAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tip contextual ───────────────────────────────────────────────
          if (eficiencia < 40)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El sistema está usando principalmente la red pública. '
                      'Verifica que el tanque de lluvia tenga agua disponible.',
                      style: TextStyle(fontSize: 11, color: Colors.orange, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else if (eficiencia >= 70)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.eco, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¡Excelente! Más del 70% del agua usada hoy provino del tanque de lluvia.',
                      style: TextStyle(fontSize: 11, color: Colors.greenAccent, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        color: Colors.white.withAlpha(80), letterSpacing: 2,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares compartidos
// ══════════════════════════════════════════════════════════════════════════════

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double litros;
  final Color color;
  final String sublabel;
  const _VolumeCard({
    required this.icon, required this.label,
    required this.litros, required this.color, required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text('${litros.toStringAsFixed(1)} L',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(sublabel,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricRow({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70))),
        Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String mensaje;
  const _EmptyChart({this.mensaje = 'No hay datos disponibles.\nCorre el simulador y el bridge para generar lecturas.'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 56, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No se pudo conectar con el servidor',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Asegúrate de que el bridge esté corriendo\n(node index.js en backend_iot)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
