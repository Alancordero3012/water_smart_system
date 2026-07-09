import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/models/app_event.dart';
import '../../domain/event_log_provider.dart';
import '../shared/app_notifications.dart';

/// Wraps the app tree and monitors sensor state for anomalies.
/// Fires non-blocking floating toasts and logs events to EventLogNotifier.
///
/// Alert gating policy:
///   - CRITICAL alerts (Turbidez Crítica, Baja Presión) require
///     `fromBridgeNotification == true` — they are only fired when the
///     Node.js bridge itself republishes the alert via `agua_iot/notificaciones`.
///   - WARNING / INFO alerts remain threshold-based.
class AlertWrapper extends ConsumerWidget {
  final Widget? child;
  const AlertWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<WaterSystemState>(processedSystemStateProvider,
        (previous, next) {
      if (previous == null) return;

      // ── Critical alerts — gated on bridge notification ─────────────
      if (next.fromBridgeNotification) {
        if (next.streetPressure < 10.0 && previous.streetPressure >= 10.0) {
          _fire(
            context, ref,
            '⚠️  Baja presión detectada: ${next.streetPressure.toStringAsFixed(1)} PSI',
            EventSeverity.critical,
          );
        }
        if (next.turbidity > 50.0 && previous.turbidity <= 50.0) {
          _fire(
            context, ref,
            '⛔  Turbidez crítica: ${next.turbidity.toStringAsFixed(1)} NTU',
            EventSeverity.critical,
          );
        }
        // Tanque físicamente vacío (confirmado por reed switch S0 del ESP32)
        if (next.tanqueCalleVacio && !previous.tanqueCalleVacio) {
          _fire(
            context, ref,
            '🔴  Tanque CALLE vacío confirmado por sensor físico',
            EventSeverity.critical,
          );
        }
        if (next.tanqueLluviaVacio && !previous.tanqueLluviaVacio) {
          _fire(
            context, ref,
            '🔴  Tanque LLUVIA vacío confirmado por sensor físico',
            EventSeverity.critical,
          );
        }
        return; // Skip threshold-based logic for bridge-notification events
      }

      // ── Pressure warning (threshold-based) ───────────────────────────
      if (next.streetPressure < 15.0 && previous.streetPressure >= 15.0) {
        _fire(
          context, ref,
          'Presión por debajo del umbral: ${next.streetPressure.toStringAsFixed(1)} PSI',
          EventSeverity.warning,
        );
      } else if (next.streetPressure >= 10.0 && previous.streetPressure < 10.0) {
        _fire(
          context, ref,
          '✓ Presión normalizada: ${next.streetPressure.toStringAsFixed(1)} PSI',
          EventSeverity.info,
        );
      }

      // ── Turbidity warning (threshold-based) ──────────────────────────
      if (next.turbidity > 10.0 && previous.turbidity <= 10.0) {
        _fire(
          context, ref,
          '⚠️  Turbidez elevada: ${next.turbidity.toStringAsFixed(1)} NTU',
          EventSeverity.warning,
        );
      } else if (next.turbidity <= 10.0 && previous.turbidity > 10.0) {
        _fire(
          context, ref,
          '✓ Calidad del agua normalizada',
          EventSeverity.info,
        );
      }

      // ── Tank level alerts ─────────────────────────────────────────────
      if (next.rainTankLevel < 10.0 && previous.rainTankLevel >= 10.0) {
        _fire(
          context, ref,
          '⚠️  Tanque lluvia crítico: ${next.rainTankLevel.toStringAsFixed(1)}%',
          EventSeverity.critical,
        );
      }
      if (next.streetTankLevel < 10.0 && previous.streetTankLevel >= 10.0) {
        _fire(
          context, ref,
          '⚠️  Tanque calle crítico: ${next.streetTankLevel.toStringAsFixed(1)}%',
          EventSeverity.critical,
        );
      }

      // ── Source auto-switch ────────────────────────────────────────────
      if (previous.activeSource == 'lluvia' &&
          next.activeSource == 'calle' &&
          next.rainTankLevel < 15.0) {
        _fire(
          context, ref,
          'ℹ️  Reserva baja: cambiando a red pública',
          EventSeverity.info,
        );
      }

      // ── Flow stopped (pump on but solenoid closed) ────────────────────
      if (next.isPumpActive && !next.isSolenoidOpen &&
          next.flowRate == 0 && previous.flowRate > 0) {
        _fire(
          context, ref,
          'Flujo detenido: solenoide cerrada con bomba activa',
          EventSeverity.warning,
        );
      }
    });

    return child ?? const SizedBox();
  }

  void _fire(
    BuildContext context,
    WidgetRef ref,
    String message,
    EventSeverity severity,
  ) {
    // 1. Log the event
    ref.read(eventLogProvider.notifier).add(
          AppEvent(message: message, severity: severity),
        );

    // 2. Show non-blocking floating toast
    if (context.mounted) {
      AppNotifications.show(
        context,
        message,
        type: switch (severity) {
          EventSeverity.critical => NotificationType.error,
          EventSeverity.warning  => NotificationType.warning,
          EventSeverity.info     => NotificationType.info,
        },
        duration: const Duration(seconds: 4),
      );
    }
  }
}
