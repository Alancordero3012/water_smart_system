import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/models/water_system_state.dart';
import 'widgets/manual_control_widget.dart';
import 'widgets/tank_gauge_widget.dart';
import 'widgets/cost_savings_widget.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/glass_container.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to the processed state (rules applied)
    final systemState = ref.watch(processedSystemStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Manual refresh logic if needed
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tank Levels Section (Vertical Gauges)
              const Text(
                'Niveles de Agua',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200, // Fixed height for gauges
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TankGaugeWidget(
                        label: 'Tanque Lluvia',
                        level: systemState.rainTankLevel,
                        color: Colors.blueAccent,
                        icon: Icons.cloud_queue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TankGaugeWidget(
                        label: 'Tanque Calle',
                        level: systemState.streetTankLevel,
                        color: Colors.lightBlue,
                        icon: Icons.location_city,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Status Section (Clean Cards)
              const Text(
                'Estado del Sistema',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildCompactStatus(systemState),

              const SizedBox(height: 24),

              // 3. Compact Manual Control
              const ManualControlWidget(),
              const SizedBox(height: 16),
              const CostSavingsWidget(),

              const SizedBox(height: 24),
              // Shortcut to Charts
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                icon: const Icon(Icons.show_chart),
                label: const Text('Ver Historial de Consumo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatus(WaterSystemState state) {
    return GlassContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusItem(
                icon: state.activeSource == 'lluvia'
                    ? Icons.water_drop
                    : Icons.public,
                label: 'Fuente',
                value: state.activeSource.toUpperCase(),
                color: state.activeSource == 'lluvia'
                    ? Colors.blue
                    : Colors.orange,
              ),
              _buildStatusItem(
                icon: Icons.speed,
                label: 'Presión',
                value: '${state.streetPressure.toStringAsFixed(1)} PSI',
                color: state.streetPressure < 10
                    ? Colors.redAccent
                    : Colors.greenAccent,
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusItem(
                icon: Icons.power,
                label: 'Bomba',
                value: state.isPumpActive ? 'ON' : 'OFF',
                color: state.isPumpActive ? Colors.greenAccent : Colors.grey,
              ),
              _buildStatusItem(
                icon: Icons.opacity,
                label: 'Turbidez',
                value: '${state.turbidity.toStringAsFixed(1)} NTU',
                color: state.turbidity > 50
                    ? Colors.redAccent
                    : Colors.cyanAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
