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
    @Default(false) bool isPumpActive,
    @Default(false) bool isSolenoidOpen,
    @Default('lluvia') String activeSource,
    /// True only when this state update was triggered by a message on
    /// `agua_iot/notificaciones` (published by the Node.js bridge after
    /// its own threshold checks). Reset to false on every regular sensor update.
    @Default(false) bool fromBridgeNotification,
  }) = _WaterSystemState;

  factory WaterSystemState.fromJson(Map<String, dynamic> json) =>
      _$WaterSystemStateFromJson(json);
}

