import 'package:freezed_annotation/freezed_annotation.dart';

part 'water_system_state.freezed.dart';
part 'water_system_state.g.dart';

@freezed
class WaterSystemState with _$WaterSystemState {
  const factory WaterSystemState({
    @Default(0.0) double rainTankLevel,
    @Default(0.0) double streetTankLevel,
    @Default(0.0) double flowRate,
    @Default(0.0) double streetPressure,
    @Default(0.0) double turbidity,

    // BombaButton standalone — agua_iot/actuadores/bomba (NO comparte con Fuentes)
    @Default(false) bool isPumpActive,
    @Default(false) bool isSolenoidOpen,

    // Fuente Calle — bomba_calle + solenoide_calle
    @Default(false) bool isBombaCalleActive,
    @Default(false) bool isSolenoideCalleOpen,

    // Fuente Lluvia — bomba_lluvia + solenoide_lluvia
    @Default(false) bool isBombaLluviaActive,
    @Default(false) bool isSoleLluviaOpen,

    // —— Reed switches individuales Tanque Calle (IDs 8–10) ——
    // true = sensor detecta agua (LOW en el ESP32)
    @Default(false) bool calleS0,    // sensor_0   (nivel 0%)
    @Default(false) bool calleS50,   // sensor_50  (nivel 50%)
    @Default(false) bool calleS100,  // sensor_100 (nivel 100%)

    // —— Reed switches individuales Tanque Lluvia (IDs 11–13) ——
    @Default(false) bool lluviaS0,   // sensor_0   (nivel 0%)
    @Default(false) bool lluviaS50,  // sensor_50  (nivel 50%)
    @Default(false) bool lluviaS100, // sensor_100 (nivel 100%)

    @Default('lluvia') String activeSource,

    /// Falla detectada actualmente por el motor de reglas.
    /// '' = sin falla. Posibles valores:
    /// 'rotura_tuberia_calle' | 'rotura_tuberia_lluvia'
    /// 'fuga_detectada' | 'presion_critica_alta'
    /// 'sensor_inconsistente_calle' | 'sensor_inconsistente_lluvia'
    /// 'agua_turbia_activa' | 'sin_fuente_disponible' | 'failover_automatico'
    @Default('') String detectedFault,

    /// Última acción autónoma ejecutada (texto para el log de eventos).
    @Default('') String autoActionLog,

    /// True cuando el sistema está operando en la fuente de respaldo
    /// por un failover automático (no por elección manual del usuario).
    @Default(false) bool failoverActive,

    /// True solo cuando el update viene de `agua_iot/notificaciones`.
    @Default(false) bool fromBridgeNotification,

    /// Alertas de tanque vacío disparadas por el bridge.
    @Default(false) bool tanqueCalleVacio,
    @Default(false) bool tanqueLluviaVacio,

    // ── Hardware Health Status (Reglas 8-13) ──────────────────────────────
    // true = sensor enviando datos correctamente

    /// Regla 8: Sensor de presión online (publica datos < 60s).
    @Default(true) bool sensorPresionOnline,

    /// Regla 8: Sensor de flujo online (publica datos < 60s).
    @Default(true) bool sensorFlujoOnline,

    /// Regla 8: Sensores de nivel de tanques online.
    @Default(true) bool sensoresNivelOnline,

    /// Regla 11: ESP32 de control (actuadores) tiene heartbeat reciente.
    @Default(true) bool esp32ControlOnline,

    /// Regla 9: Relé no responde a comando enviado.
    @Default(false) bool releAtascado,

    /// Regla 10: Motor sobrecargado — presión subió muy rápido.
    @Default(false) bool motorSobrecargado,

    /// Regla 12: Sensor de flujo reporta 0.00 exacto por mucho tiempo
    /// (posible tapón en el sensor, no rotura de tubo).
    @Default(false) bool sensorFlujoAtascado,

    /// Regla 13: Sensor de presión reporta 0.00 exacto por mucho tiempo
    /// (posible cable ADC desconectado, no presión real baja).
    @Default(false) bool sensorPresionAtascado,
  }) = _WaterSystemState;

  factory WaterSystemState.fromJson(Map<String, dynamic> json) =>
      _$WaterSystemStateFromJson(json);
}

