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
    @Default('lluvia') String activeSource,
    /// True solo cuando el update viene de `agua_iot/notificaciones`.
    @Default(false) bool fromBridgeNotification,
  }) = _WaterSystemState;

  factory WaterSystemState.fromJson(Map<String, dynamic> json) =>
      _$WaterSystemStateFromJson(json);
}

