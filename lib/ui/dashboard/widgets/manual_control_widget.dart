import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers.dart';

/// Compact manual control widget with pump, solenoid, and source selector.
class ManualControlWidget extends ConsumerWidget {
  const ManualControlWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(processedSystemStateProvider);
    final repo = ref.read(waterDataRepositoryProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Pump + Solenoid toggles
          Row(
            children: [
              Expanded(
                child: _CompactToggle(
                  label: 'Bomba',
                  icon: Icons.power_settings_new,
                  isActive: state.isPumpActive,
                  onChanged: (v) {
                    repo.sendCommand('pump', v ? 'ON' : 'OFF');
                    _showSnack(context, 'Bomba ${v ? "ON" : "OFF"}');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactToggle(
                  label: 'Solenoide',
                  icon: Icons.adjust,
                  isActive: state.isSolenoidOpen,
                  activeLabel: 'OPEN',
                  inactiveLabel: 'CLOSED',
                  onChanged: (v) {
                    repo.sendCommand('solenoid', v ? 'OPEN' : 'CLOSED');
                    _showSnack(context, 'Solenoide ${v ? "OPEN" : "CLOSED"}');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withAlpha(10)),
          const SizedBox(height: 14),

          // Row 2: Source selector
          Row(
            children: [
              Text(
                'FUENTE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withAlpha(100),
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 36,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'lluvia',
                      label: Text('Lluvia', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.cloud_queue, size: 14),
                    ),
                    ButtonSegment(
                      value: 'calle',
                      label: Text('Calle', style: TextStyle(fontSize: 11)),
                      icon: Icon(Icons.location_city, size: 14),
                    ),
                  ],
                  selected: {state.activeSource},
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    side: WidgetStateProperty.all(
                      BorderSide(color: Colors.white.withAlpha(30)),
                    ),
                    foregroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.black;
                      }
                      return Colors.white70;
                    }),
                    backgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF00E5FF);
                      }
                      return Colors.transparent;
                    }),
                  ),
                  onSelectionChanged: (Set<String> sel) {
                    final v = sel.first;
                    repo.sendCommand('source', v);
                    _showSnack(context, 'Fuente: ${v.toUpperCase()}');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Compact toggle button for actuators
class _CompactToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final String activeLabel;
  final String inactiveLabel;
  final ValueChanged<bool> onChanged;

  const _CompactToggle({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onChanged,
    this.activeLabel = 'ON',
    this.inactiveLabel = 'OFF',
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.greenAccent : Colors.redAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!isActive),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(180),
                ),
              ),
            ),
            Text(
              isActive ? activeLabel : inactiveLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
