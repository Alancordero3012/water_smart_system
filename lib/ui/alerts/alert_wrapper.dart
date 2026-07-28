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
///   - CRITICAL alerts (Baja Presión, Tanque vacío) require
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

      // ── Auto-action log from SmartRulesService ───────────────────────
      // The rules engine sets autoActionLog when it sends a command autonomously.
      if (next.autoActionLog.isNotEmpty &&
          next.autoActionLog != previous.autoActionLog) {
        final severity = next.autoActionLog.startsWith('⛔') ||
                next.autoActionLog.startsWith('🚨')
            ? EventSeverity.critical
            : next.autoActionLog.startsWith('⚠️')
                ? EventSeverity.warning
                : EventSeverity.info;
        _fire(context, ref, next.autoActionLog, severity);
      }

      // ── Fault detection changes ───────────────────────────────────────
      if (next.detectedFault != previous.detectedFault &&
          next.detectedFault.isNotEmpty) {
        final fault = next.detectedFault;

        // Rotura de tubería
        if (fault.startsWith('rotura_tuberia_')) {
          final fuente = fault.replaceFirst('rotura_tuberia_', '').toUpperCase();
          _fire(context, ref,
              '⛔ Rotura/bloqueo detectado en línea $fuente — failover automático activado',
              EventSeverity.critical);
        }
        // Fuga
        else if (fault == 'fuga_detectada') {
          _fire(context, ref,
              '⚠️ Fuga detectada — hay flujo activo con el sistema apagado',
              EventSeverity.warning);
        }
        // Presión alta
        else if (fault.startsWith('presion_critica_alta_')) {
          _fire(context, ref,
              '⚠️ Presión anómala alta — bomba detenida para proteger tuberías',
              EventSeverity.warning);
        }
        // Presión baja → failover
        else if (fault.startsWith('presion_baja_')) {
          final fuente = fault.replaceFirst('presion_baja_', '').toUpperCase();
          _fire(context, ref,
              '⚠️ Presión baja en $fuente — cambiando a fuente de respaldo',
              EventSeverity.warning);
        }
        // Sensor inconsistente
        else if (fault.startsWith('sensor_inconsistente_')) {
          final fuente = fault.replaceFirst('sensor_inconsistente_', '').toUpperCase();
          _fire(context, ref,
              '🔧 Sensor físico inconsistente en Tanque $fuente — verificar hardware',
              EventSeverity.warning);
        }
        // Agua turbia con sistema activo
        else if (fault == 'agua_turbia_activa') {
          _fire(context, ref,
              '⛔ Agua turbia detectada — distribución detenida automáticamente',
              EventSeverity.critical);
        }
        // Sin fuente disponible
        else if (fault == 'sin_fuente_disponible') {
          _fire(context, ref,
              '🚨 CRÍTICO: Ninguna fuente disponible — sistema completamente detenido',
              EventSeverity.critical);
        }
        // ESP32 offline (Regla 11)
        else if (fault.startsWith('esp32_offline_')) {
          final fuente = fault.replaceFirst('esp32_offline_', '').toUpperCase();
          _fire(context, ref,
              '⚠️ ESP32 de control ($fuente) sin respuesta — actuadores posiblemente sin control',
              EventSeverity.critical);
        }
      }

      // ── ESP32 volvió online ───────────────────────────────────────────
      if (!previous.esp32ControlOnline && next.esp32ControlOnline) {
        _fire(context, ref,
            '✅ ESP32 de control restaurado — actuadores nuevamente disponibles',
            EventSeverity.info);
      }

      // ── Failover activo → restaurado ──────────────────────────────────
      if (previous.failoverActive && !next.failoverActive) {
        _fire(context, ref,
            'ℹ️ Sistema volvió a la fuente principal — failover desactivado',
            EventSeverity.info);
      }

      // ── Critical alerts — gated on bridge notification ─────────────
      if (next.fromBridgeNotification) {
        if (next.streetPressure < 10.0 && previous.streetPressure >= 10.0) {
          _fire(
            context, ref,
            '⚠️  Baja presión detectada: ${next.streetPressure.toStringAsFixed(1)} PSI',
            EventSeverity.critical,
          );
        }
        // DESACTIVADO: sensor de turbidez no verificado en hardware actual
        // if (next.turbidity > 50.0 && previous.turbidity <= 50.0) {
        //   _fire(
        //     context, ref,
        //     '⛔  Turbidez crítica: ${next.turbidity.toStringAsFixed(1)} NTU',
        //     EventSeverity.critical,
        //   );
        // }
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

      // ── Turbidity warning ─────────────────────────────────────────────────────────
      // DESACTIVADO: sensor de turbidez no verificado en hardware actual
      // if (next.turbidity > 10.0 && previous.turbidity <= 10.0) {
      //   _fire(context, ref,
      //     '⚠️  Turbidez elevada: ${next.turbidity.toStringAsFixed(1)} NTU',
      //     EventSeverity.warning);
      // } else if (next.turbidity <= 10.0 && previous.turbidity > 10.0) {
      //   _fire(context, ref, '✓ Calidad del agua normalizada', EventSeverity.info);
      // }

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
