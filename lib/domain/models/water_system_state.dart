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

    /// True solo cuando el update viene de `agua_iot/notificaciones`.
    @Default(false) bool fromBridgeNotification,

    /// Alertas de tanque vacío disparadas por el bridge.
    @Default(false) bool tanqueCalleVacio,
    @Default(false) bool tanqueLluviaVacio,
  }) = _WaterSystemState;

  factory WaterSystemState.fromJson(Map<String, dynamic> json) =>
      _$WaterSystemStateFromJson(json);
}

