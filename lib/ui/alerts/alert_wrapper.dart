import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';

class AlertWrapper extends ConsumerWidget {
  final Widget? child;
  const AlertWrapper({super.key, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(processedSystemStateProvider, (previous, next) {
      // 1. Low Pressure Alert (Critical)
      if (next.streetPressure < 10.0 &&
          (previous == null || previous.streetPressure >= 10.0)) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: const Text(
              '⚠️  ALERTA CRÍTICA: Baja presión en la red pública detectada!',
            ),
            backgroundColor: Colors.redAccent,
            actions: [
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      } else if (next.streetPressure >= 10.0 &&
          previous != null &&
          previous.streetPressure < 10.0) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }

      // 2. High Turbidity Alert (Critical)
      if (next.turbidity > 50.0 &&
          (previous == null || previous.turbidity <= 50.0)) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: const Text(
              '⛔  ALERTA DE CALIDAD: Turbidez alta! Entrada de agua bloqueada.',
            ),
            backgroundColor: Colors.orange[800],
            actions: [
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text(
                  'ENTENDIDO',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      } else if (next.turbidity <= 50.0 &&
          previous != null &&
          previous.turbidity > 50.0) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }

      // 3. Emergency Mode (Example: Source changed automatically)
      if (previous != null &&
          previous.activeSource == 'rain' &&
          next.activeSource == 'street' &&
          next.rainTankLevel < 15.0) {
        // Assuming 15 is threshold
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Reserva baja: Cambiando a red pública.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });

    return child ?? const SizedBox();
  }
}
