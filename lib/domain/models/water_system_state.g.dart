// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_system_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$WaterSystemStateImpl _$$WaterSystemStateImplFromJson(
  Map<String, dynamic> json,
) => _$WaterSystemStateImpl(
  rainTankLevel: (json['rainTankLevel'] as num?)?.toDouble() ?? 0.0,
  streetTankLevel: (json['streetTankLevel'] as num?)?.toDouble() ?? 0.0,
  flowRate: (json['flowRate'] as num?)?.toDouble() ?? 0.0,
  streetPressure: (json['streetPressure'] as num?)?.toDouble() ?? 0.0,
  turbidity: (json['turbidity'] as num?)?.toDouble() ?? 0.0,
  isPumpActive: json['isPumpActive'] as bool? ?? false,
  isSolenoidOpen: json['isSolenoidOpen'] as bool? ?? false,
  isBombaCalleActive: json['isBombaCalleActive'] as bool? ?? false,
  isSolenoideCalleOpen: json['isSolenoideCalleOpen'] as bool? ?? false,
  isBombaLluviaActive: json['isBombaLluviaActive'] as bool? ?? false,
  isSoleLluviaOpen: json['isSoleLluviaOpen'] as bool? ?? false,
  activeSource: json['activeSource'] as String? ?? 'lluvia',
  fromBridgeNotification: json['fromBridgeNotification'] as bool? ?? false,
);

Map<String, dynamic> _$$WaterSystemStateImplToJson(
  _$WaterSystemStateImpl instance,
) => <String, dynamic>{
  'rainTankLevel': instance.rainTankLevel,
  'streetTankLevel': instance.streetTankLevel,
  'flowRate': instance.flowRate,
  'streetPressure': instance.streetPressure,
  'turbidity': instance.turbidity,
  'isPumpActive': instance.isPumpActive,
  'isSolenoidOpen': instance.isSolenoidOpen,
  'isBombaCalleActive': instance.isBombaCalleActive,
  'isSolenoideCalleOpen': instance.isSolenoideCalleOpen,
  'isBombaLluviaActive': instance.isBombaLluviaActive,
  'isSoleLluviaOpen': instance.isSoleLluviaOpen,
  'activeSource': instance.activeSource,
  'fromBridgeNotification': instance.fromBridgeNotification,
};
