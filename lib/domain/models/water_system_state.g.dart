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
  calleS0: json['calleS0'] as bool? ?? false,
  calleS50: json['calleS50'] as bool? ?? false,
  calleS100: json['calleS100'] as bool? ?? false,
  lluviaS0: json['lluviaS0'] as bool? ?? false,
  lluviaS50: json['lluviaS50'] as bool? ?? false,
  lluviaS100: json['lluviaS100'] as bool? ?? false,
  activeSource: json['activeSource'] as String? ?? 'lluvia',
  fromBridgeNotification: json['fromBridgeNotification'] as bool? ?? false,
  tanqueCalleVacio: json['tanqueCalleVacio'] as bool? ?? false,
  tanqueLluviaVacio: json['tanqueLluviaVacio'] as bool? ?? false,
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
  'calleS0': instance.calleS0,
  'calleS50': instance.calleS50,
  'calleS100': instance.calleS100,
  'lluviaS0': instance.lluviaS0,
  'lluviaS50': instance.lluviaS50,
  'lluviaS100': instance.lluviaS100,
  'activeSource': instance.activeSource,
  'fromBridgeNotification': instance.fromBridgeNotification,
  'tanqueCalleVacio': instance.tanqueCalleVacio,
  'tanqueLluviaVacio': instance.tanqueLluviaVacio,
};
