import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/mqtt_service.dart';
import '../../../domain/providers.dart';
import '../../shared/glass_container.dart';

class ManualControlWidget extends ConsumerWidget {
  const ManualControlWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch system state to update UI
    final systemState = ref.watch(processedSystemStateProvider);
    // Read MQTT service to publish commands
    final mqttService = ref.read(mqttServiceProvider);

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Control Manual',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Pump Control
          SwitchListTile(
            title: const Text(
              'Bomba Hidráulica',
              style: TextStyle(color: Colors.white70),
            ),
            subtitle: Text(
              systemState.isPumpActive
                  ? 'Forzada ENCENDIDA'
                  : 'Automático / Apagada',
              style: TextStyle(
                color: systemState.isPumpActive
                    ? Colors.greenAccent
                    : Colors.white38,
              ),
            ),
            value: systemState.isPumpActive,
            activeColor: Colors.greenAccent,
            secondary: const Icon(
              Icons.power_settings_new,
              color: Colors.white70,
            ),
            onChanged: (value) {
              mqttService.publishCommand('pump', value ? 'ON' : 'OFF');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Enviando comando: Bomba ${value ? "ON" : "OFF"}',
                  ),
                ),
              );
            },
          ),

          const Divider(color: Colors.white24),
          const SizedBox(height: 8),

          // Source Control
          const Text(
            'Fuente de Agua',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'lluvia',
                  label: Text('Lluvia'),
                  icon: Icon(Icons.cloud_queue),
                ),
                ButtonSegment(
                  value: 'calle',
                  label: Text('Calle'),
                  icon: Icon(Icons.location_city),
                ),
              ],
              selected: {systemState.activeSource},
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStateProperty.all(
                  BorderSide(color: Colors.white24),
                ),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return Colors.black;
                  return Colors.white;
                }),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return Colors.cyanAccent;
                  return Colors.transparent;
                }),
              ),
              onSelectionChanged: (Set<String> newSelection) {
                final newValue = newSelection.first;
                mqttService.publishCommand('source', newValue);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cambiando fuente a: ${newValue.toUpperCase()}',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
