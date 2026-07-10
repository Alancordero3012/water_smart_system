// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'water_system_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

WaterSystemState _$WaterSystemStateFromJson(Map<String, dynamic> json) {
  return _WaterSystemState.fromJson(json);
}

/// @nodoc
mixin _$WaterSystemState {
  double get rainTankLevel => throw _privateConstructorUsedError;
  double get streetTankLevel => throw _privateConstructorUsedError;
  double get flowRate => throw _privateConstructorUsedError;
  double get streetPressure => throw _privateConstructorUsedError;
  double get turbidity =>
      throw _privateConstructorUsedError; // BombaButton standalone — agua_iot/actuadores/bomba (NO comparte con Fuentes)
  bool get isPumpActive => throw _privateConstructorUsedError;
  bool get isSolenoidOpen =>
      throw _privateConstructorUsedError; // Fuente Calle — bomba_calle + solenoide_calle
  bool get isBombaCalleActive => throw _privateConstructorUsedError;
  bool get isSolenoideCalleOpen =>
      throw _privateConstructorUsedError; // Fuente Lluvia — bomba_lluvia + solenoide_lluvia
  bool get isBombaLluviaActive => throw _privateConstructorUsedError;
  bool get isSoleLluviaOpen =>
      throw _privateConstructorUsedError; // —— Reed switches individuales Tanque Calle (IDs 8–10) ——
  // true = sensor detecta agua (LOW en el ESP32)
  bool get calleS0 =>
      throw _privateConstructorUsedError; // sensor_0   (nivel 0%)
  bool get calleS50 =>
      throw _privateConstructorUsedError; // sensor_50  (nivel 50%)
  bool get calleS100 =>
      throw _privateConstructorUsedError; // sensor_100 (nivel 100%)
  // —— Reed switches individuales Tanque Lluvia (IDs 11–13) ——
  bool get lluviaS0 =>
      throw _privateConstructorUsedError; // sensor_0   (nivel 0%)
  bool get lluviaS50 =>
      throw _privateConstructorUsedError; // sensor_50  (nivel 50%)
  bool get lluviaS100 =>
      throw _privateConstructorUsedError; // sensor_100 (nivel 100%)
  String get activeSource => throw _privateConstructorUsedError;

  /// Falla detectada actualmente por el motor de reglas.
  /// '' = sin falla. Posibles valores:
  /// 'rotura_tuberia_calle' | 'rotura_tuberia_lluvia'
  /// 'fuga_detectada' | 'presion_critica_alta'
  /// 'sensor_inconsistente_calle' | 'sensor_inconsistente_lluvia'
  /// 'agua_turbia_activa' | 'sin_fuente_disponible' | 'failover_automatico'
  String get detectedFault => throw _privateConstructorUsedError;

  /// Última acción autónoma ejecutada (texto para el log de eventos).
  String get autoActionLog => throw _privateConstructorUsedError;

  /// True cuando el sistema está operando en la fuente de respaldo
  /// por un failover automático (no por elección manual del usuario).
  bool get failoverActive => throw _privateConstructorUsedError;

  /// True solo cuando el update viene de `agua_iot/notificaciones`.
  bool get fromBridgeNotification => throw _privateConstructorUsedError;

  /// Alertas de tanque vacío disparadas por el bridge.
  bool get tanqueCalleVacio => throw _privateConstructorUsedError;
  bool get tanqueLluviaVacio =>
      throw _privateConstructorUsedError; // ── Hardware Health Status (Reglas 8-13) ──────────────────────────────
  // true = sensor enviando datos correctamente
  /// Regla 8: Sensor de presión online (publica datos < 60s).
  bool get sensorPresionOnline => throw _privateConstructorUsedError;

  /// Regla 8: Sensor de flujo online (publica datos < 60s).
  bool get sensorFlujoOnline => throw _privateConstructorUsedError;

  /// Regla 8: Sensores de nivel de tanques online.
  bool get sensoresNivelOnline => throw _privateConstructorUsedError;

  /// Regla 11: ESP32 de control (actuadores) tiene heartbeat reciente.
  bool get esp32ControlOnline => throw _privateConstructorUsedError;

  /// Regla 9: Relé no responde a comando enviado.
  bool get releAtascado => throw _privateConstructorUsedError;

  /// Regla 10: Motor sobrecargado — presión subió muy rápido.
  bool get motorSobrecargado => throw _privateConstructorUsedError;

  /// Regla 12: Sensor de flujo reporta 0.00 exacto por mucho tiempo
  /// (posible tapón en el sensor, no rotura de tubo).
  bool get sensorFlujoAtascado => throw _privateConstructorUsedError;

  /// Regla 13: Sensor de presión reporta 0.00 exacto por mucho tiempo
  /// (posible cable ADC desconectado, no presión real baja).
  bool get sensorPresionAtascado => throw _privateConstructorUsedError;

  /// Serializes this WaterSystemState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WaterSystemStateCopyWith<WaterSystemState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WaterSystemStateCopyWith<$Res> {
  factory $WaterSystemStateCopyWith(
    WaterSystemState value,
    $Res Function(WaterSystemState) then,
  ) = _$WaterSystemStateCopyWithImpl<$Res, WaterSystemState>;
  @useResult
  $Res call({
    double rainTankLevel,
    double streetTankLevel,
    double flowRate,
    double streetPressure,
    double turbidity,
    bool isPumpActive,
    bool isSolenoidOpen,
    bool isBombaCalleActive,
    bool isSolenoideCalleOpen,
    bool isBombaLluviaActive,
    bool isSoleLluviaOpen,
    bool calleS0,
    bool calleS50,
    bool calleS100,
    bool lluviaS0,
    bool lluviaS50,
    bool lluviaS100,
    String activeSource,
    String detectedFault,
    String autoActionLog,
    bool failoverActive,
    bool fromBridgeNotification,
    bool tanqueCalleVacio,
    bool tanqueLluviaVacio,
    bool sensorPresionOnline,
    bool sensorFlujoOnline,
    bool sensoresNivelOnline,
    bool esp32ControlOnline,
    bool releAtascado,
    bool motorSobrecargado,
    bool sensorFlujoAtascado,
    bool sensorPresionAtascado,
  });
}

/// @nodoc
class _$WaterSystemStateCopyWithImpl<$Res, $Val extends WaterSystemState>
    implements $WaterSystemStateCopyWith<$Res> {
  _$WaterSystemStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rainTankLevel = null,
    Object? streetTankLevel = null,
    Object? flowRate = null,
    Object? streetPressure = null,
    Object? turbidity = null,
    Object? isPumpActive = null,
    Object? isSolenoidOpen = null,
    Object? isBombaCalleActive = null,
    Object? isSolenoideCalleOpen = null,
    Object? isBombaLluviaActive = null,
    Object? isSoleLluviaOpen = null,
    Object? calleS0 = null,
    Object? calleS50 = null,
    Object? calleS100 = null,
    Object? lluviaS0 = null,
    Object? lluviaS50 = null,
    Object? lluviaS100 = null,
    Object? activeSource = null,
    Object? detectedFault = null,
    Object? autoActionLog = null,
    Object? failoverActive = null,
    Object? fromBridgeNotification = null,
    Object? tanqueCalleVacio = null,
    Object? tanqueLluviaVacio = null,
    Object? sensorPresionOnline = null,
    Object? sensorFlujoOnline = null,
    Object? sensoresNivelOnline = null,
    Object? esp32ControlOnline = null,
    Object? releAtascado = null,
    Object? motorSobrecargado = null,
    Object? sensorFlujoAtascado = null,
    Object? sensorPresionAtascado = null,
  }) {
    return _then(
      _value.copyWith(
            rainTankLevel: null == rainTankLevel
                ? _value.rainTankLevel
                : rainTankLevel // ignore: cast_nullable_to_non_nullable
                      as double,
            streetTankLevel: null == streetTankLevel
                ? _value.streetTankLevel
                : streetTankLevel // ignore: cast_nullable_to_non_nullable
                      as double,
            flowRate: null == flowRate
                ? _value.flowRate
                : flowRate // ignore: cast_nullable_to_non_nullable
                      as double,
            streetPressure: null == streetPressure
                ? _value.streetPressure
                : streetPressure // ignore: cast_nullable_to_non_nullable
                      as double,
            turbidity: null == turbidity
                ? _value.turbidity
                : turbidity // ignore: cast_nullable_to_non_nullable
                      as double,
            isPumpActive: null == isPumpActive
                ? _value.isPumpActive
                : isPumpActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSolenoidOpen: null == isSolenoidOpen
                ? _value.isSolenoidOpen
                : isSolenoidOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            isBombaCalleActive: null == isBombaCalleActive
                ? _value.isBombaCalleActive
                : isBombaCalleActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSolenoideCalleOpen: null == isSolenoideCalleOpen
                ? _value.isSolenoideCalleOpen
                : isSolenoideCalleOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            isBombaLluviaActive: null == isBombaLluviaActive
                ? _value.isBombaLluviaActive
                : isBombaLluviaActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSoleLluviaOpen: null == isSoleLluviaOpen
                ? _value.isSoleLluviaOpen
                : isSoleLluviaOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            calleS0: null == calleS0
                ? _value.calleS0
                : calleS0 // ignore: cast_nullable_to_non_nullable
                      as bool,
            calleS50: null == calleS50
                ? _value.calleS50
                : calleS50 // ignore: cast_nullable_to_non_nullable
                      as bool,
            calleS100: null == calleS100
                ? _value.calleS100
                : calleS100 // ignore: cast_nullable_to_non_nullable
                      as bool,
            lluviaS0: null == lluviaS0
                ? _value.lluviaS0
                : lluviaS0 // ignore: cast_nullable_to_non_nullable
                      as bool,
            lluviaS50: null == lluviaS50
                ? _value.lluviaS50
                : lluviaS50 // ignore: cast_nullable_to_non_nullable
                      as bool,
            lluviaS100: null == lluviaS100
                ? _value.lluviaS100
                : lluviaS100 // ignore: cast_nullable_to_non_nullable
                      as bool,
            activeSource: null == activeSource
                ? _value.activeSource
                : activeSource // ignore: cast_nullable_to_non_nullable
                      as String,
            detectedFault: null == detectedFault
                ? _value.detectedFault
                : detectedFault // ignore: cast_nullable_to_non_nullable
                      as String,
            autoActionLog: null == autoActionLog
                ? _value.autoActionLog
                : autoActionLog // ignore: cast_nullable_to_non_nullable
                      as String,
            failoverActive: null == failoverActive
                ? _value.failoverActive
                : failoverActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            fromBridgeNotification: null == fromBridgeNotification
                ? _value.fromBridgeNotification
                : fromBridgeNotification // ignore: cast_nullable_to_non_nullable
                      as bool,
            tanqueCalleVacio: null == tanqueCalleVacio
                ? _value.tanqueCalleVacio
                : tanqueCalleVacio // ignore: cast_nullable_to_non_nullable
                      as bool,
            tanqueLluviaVacio: null == tanqueLluviaVacio
                ? _value.tanqueLluviaVacio
                : tanqueLluviaVacio // ignore: cast_nullable_to_non_nullable
                      as bool,
            sensorPresionOnline: null == sensorPresionOnline
                ? _value.sensorPresionOnline
                : sensorPresionOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            sensorFlujoOnline: null == sensorFlujoOnline
                ? _value.sensorFlujoOnline
                : sensorFlujoOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            sensoresNivelOnline: null == sensoresNivelOnline
                ? _value.sensoresNivelOnline
                : sensoresNivelOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            esp32ControlOnline: null == esp32ControlOnline
                ? _value.esp32ControlOnline
                : esp32ControlOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            releAtascado: null == releAtascado
                ? _value.releAtascado
                : releAtascado // ignore: cast_nullable_to_non_nullable
                      as bool,
            motorSobrecargado: null == motorSobrecargado
                ? _value.motorSobrecargado
                : motorSobrecargado // ignore: cast_nullable_to_non_nullable
                      as bool,
            sensorFlujoAtascado: null == sensorFlujoAtascado
                ? _value.sensorFlujoAtascado
                : sensorFlujoAtascado // ignore: cast_nullable_to_non_nullable
                      as bool,
            sensorPresionAtascado: null == sensorPresionAtascado
                ? _value.sensorPresionAtascado
                : sensorPresionAtascado // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WaterSystemStateImplCopyWith<$Res>
    implements $WaterSystemStateCopyWith<$Res> {
  factory _$$WaterSystemStateImplCopyWith(
    _$WaterSystemStateImpl value,
    $Res Function(_$WaterSystemStateImpl) then,
  ) = __$$WaterSystemStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double rainTankLevel,
    double streetTankLevel,
    double flowRate,
    double streetPressure,
    double turbidity,
    bool isPumpActive,
    bool isSolenoidOpen,
    bool isBombaCalleActive,
    bool isSolenoideCalleOpen,
    bool isBombaLluviaActive,
    bool isSoleLluviaOpen,
    bool calleS0,
    bool calleS50,
    bool calleS100,
    bool lluviaS0,
    bool lluviaS50,
    bool lluviaS100,
    String activeSource,
    String detectedFault,
    String autoActionLog,
    bool failoverActive,
    bool fromBridgeNotification,
    bool tanqueCalleVacio,
    bool tanqueLluviaVacio,
    bool sensorPresionOnline,
    bool sensorFlujoOnline,
    bool sensoresNivelOnline,
    bool esp32ControlOnline,
    bool releAtascado,
    bool motorSobrecargado,
    bool sensorFlujoAtascado,
    bool sensorPresionAtascado,
  });
}

/// @nodoc
class __$$WaterSystemStateImplCopyWithImpl<$Res>
    extends _$WaterSystemStateCopyWithImpl<$Res, _$WaterSystemStateImpl>
    implements _$$WaterSystemStateImplCopyWith<$Res> {
  __$$WaterSystemStateImplCopyWithImpl(
    _$WaterSystemStateImpl _value,
    $Res Function(_$WaterSystemStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? rainTankLevel = null,
    Object? streetTankLevel = null,
    Object? flowRate = null,
    Object? streetPressure = null,
    Object? turbidity = null,
    Object? isPumpActive = null,
    Object? isSolenoidOpen = null,
    Object? isBombaCalleActive = null,
    Object? isSolenoideCalleOpen = null,
    Object? isBombaLluviaActive = null,
    Object? isSoleLluviaOpen = null,
    Object? calleS0 = null,
    Object? calleS50 = null,
    Object? calleS100 = null,
    Object? lluviaS0 = null,
    Object? lluviaS50 = null,
    Object? lluviaS100 = null,
    Object? activeSource = null,
    Object? detectedFault = null,
    Object? autoActionLog = null,
    Object? failoverActive = null,
    Object? fromBridgeNotification = null,
    Object? tanqueCalleVacio = null,
    Object? tanqueLluviaVacio = null,
    Object? sensorPresionOnline = null,
    Object? sensorFlujoOnline = null,
    Object? sensoresNivelOnline = null,
    Object? esp32ControlOnline = null,
    Object? releAtascado = null,
    Object? motorSobrecargado = null,
    Object? sensorFlujoAtascado = null,
    Object? sensorPresionAtascado = null,
  }) {
    return _then(
      _$WaterSystemStateImpl(
        rainTankLevel: null == rainTankLevel
            ? _value.rainTankLevel
            : rainTankLevel // ignore: cast_nullable_to_non_nullable
                  as double,
        streetTankLevel: null == streetTankLevel
            ? _value.streetTankLevel
            : streetTankLevel // ignore: cast_nullable_to_non_nullable
                  as double,
        flowRate: null == flowRate
            ? _value.flowRate
            : flowRate // ignore: cast_nullable_to_non_nullable
                  as double,
        streetPressure: null == streetPressure
            ? _value.streetPressure
            : streetPressure // ignore: cast_nullable_to_non_nullable
                  as double,
        turbidity: null == turbidity
            ? _value.turbidity
            : turbidity // ignore: cast_nullable_to_non_nullable
                  as double,
        isPumpActive: null == isPumpActive
            ? _value.isPumpActive
            : isPumpActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSolenoidOpen: null == isSolenoidOpen
            ? _value.isSolenoidOpen
            : isSolenoidOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBombaCalleActive: null == isBombaCalleActive
            ? _value.isBombaCalleActive
            : isBombaCalleActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSolenoideCalleOpen: null == isSolenoideCalleOpen
            ? _value.isSolenoideCalleOpen
            : isSolenoideCalleOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBombaLluviaActive: null == isBombaLluviaActive
            ? _value.isBombaLluviaActive
            : isBombaLluviaActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSoleLluviaOpen: null == isSoleLluviaOpen
            ? _value.isSoleLluviaOpen
            : isSoleLluviaOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        calleS0: null == calleS0
            ? _value.calleS0
            : calleS0 // ignore: cast_nullable_to_non_nullable
                  as bool,
        calleS50: null == calleS50
            ? _value.calleS50
            : calleS50 // ignore: cast_nullable_to_non_nullable
                  as bool,
        calleS100: null == calleS100
            ? _value.calleS100
            : calleS100 // ignore: cast_nullable_to_non_nullable
                  as bool,
        lluviaS0: null == lluviaS0
            ? _value.lluviaS0
            : lluviaS0 // ignore: cast_nullable_to_non_nullable
                  as bool,
        lluviaS50: null == lluviaS50
            ? _value.lluviaS50
            : lluviaS50 // ignore: cast_nullable_to_non_nullable
                  as bool,
        lluviaS100: null == lluviaS100
            ? _value.lluviaS100
            : lluviaS100 // ignore: cast_nullable_to_non_nullable
                  as bool,
        activeSource: null == activeSource
            ? _value.activeSource
            : activeSource // ignore: cast_nullable_to_non_nullable
                  as String,
        detectedFault: null == detectedFault
            ? _value.detectedFault
            : detectedFault // ignore: cast_nullable_to_non_nullable
                  as String,
        autoActionLog: null == autoActionLog
            ? _value.autoActionLog
            : autoActionLog // ignore: cast_nullable_to_non_nullable
                  as String,
        failoverActive: null == failoverActive
            ? _value.failoverActive
            : failoverActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        fromBridgeNotification: null == fromBridgeNotification
            ? _value.fromBridgeNotification
            : fromBridgeNotification // ignore: cast_nullable_to_non_nullable
                  as bool,
        tanqueCalleVacio: null == tanqueCalleVacio
            ? _value.tanqueCalleVacio
            : tanqueCalleVacio // ignore: cast_nullable_to_non_nullable
                  as bool,
        tanqueLluviaVacio: null == tanqueLluviaVacio
            ? _value.tanqueLluviaVacio
            : tanqueLluviaVacio // ignore: cast_nullable_to_non_nullable
                  as bool,
        sensorPresionOnline: null == sensorPresionOnline
            ? _value.sensorPresionOnline
            : sensorPresionOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        sensorFlujoOnline: null == sensorFlujoOnline
            ? _value.sensorFlujoOnline
            : sensorFlujoOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        sensoresNivelOnline: null == sensoresNivelOnline
            ? _value.sensoresNivelOnline
            : sensoresNivelOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        esp32ControlOnline: null == esp32ControlOnline
            ? _value.esp32ControlOnline
            : esp32ControlOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        releAtascado: null == releAtascado
            ? _value.releAtascado
            : releAtascado // ignore: cast_nullable_to_non_nullable
                  as bool,
        motorSobrecargado: null == motorSobrecargado
            ? _value.motorSobrecargado
            : motorSobrecargado // ignore: cast_nullable_to_non_nullable
                  as bool,
        sensorFlujoAtascado: null == sensorFlujoAtascado
            ? _value.sensorFlujoAtascado
            : sensorFlujoAtascado // ignore: cast_nullable_to_non_nullable
                  as bool,
        sensorPresionAtascado: null == sensorPresionAtascado
            ? _value.sensorPresionAtascado
            : sensorPresionAtascado // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WaterSystemStateImpl implements _WaterSystemState {
  const _$WaterSystemStateImpl({
    this.rainTankLevel = 0.0,
    this.streetTankLevel = 0.0,
    this.flowRate = 0.0,
    this.streetPressure = 0.0,
    this.turbidity = 0.0,
    this.isPumpActive = false,
    this.isSolenoidOpen = false,
    this.isBombaCalleActive = false,
    this.isSolenoideCalleOpen = false,
    this.isBombaLluviaActive = false,
    this.isSoleLluviaOpen = false,
    this.calleS0 = false,
    this.calleS50 = false,
    this.calleS100 = false,
    this.lluviaS0 = false,
    this.lluviaS50 = false,
    this.lluviaS100 = false,
    this.activeSource = 'lluvia',
    this.detectedFault = '',
    this.autoActionLog = '',
    this.failoverActive = false,
    this.fromBridgeNotification = false,
    this.tanqueCalleVacio = false,
    this.tanqueLluviaVacio = false,
    this.sensorPresionOnline = true,
    this.sensorFlujoOnline = true,
    this.sensoresNivelOnline = true,
    this.esp32ControlOnline = true,
    this.releAtascado = false,
    this.motorSobrecargado = false,
    this.sensorFlujoAtascado = false,
    this.sensorPresionAtascado = false,
  });

  factory _$WaterSystemStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$WaterSystemStateImplFromJson(json);

  @override
  @JsonKey()
  final double rainTankLevel;
  @override
  @JsonKey()
  final double streetTankLevel;
  @override
  @JsonKey()
  final double flowRate;
  @override
  @JsonKey()
  final double streetPressure;
  @override
  @JsonKey()
  final double turbidity;
  // BombaButton standalone — agua_iot/actuadores/bomba (NO comparte con Fuentes)
  @override
  @JsonKey()
  final bool isPumpActive;
  @override
  @JsonKey()
  final bool isSolenoidOpen;
  // Fuente Calle — bomba_calle + solenoide_calle
  @override
  @JsonKey()
  final bool isBombaCalleActive;
  @override
  @JsonKey()
  final bool isSolenoideCalleOpen;
  // Fuente Lluvia — bomba_lluvia + solenoide_lluvia
  @override
  @JsonKey()
  final bool isBombaLluviaActive;
  @override
  @JsonKey()
  final bool isSoleLluviaOpen;
  // —— Reed switches individuales Tanque Calle (IDs 8–10) ——
  // true = sensor detecta agua (LOW en el ESP32)
  @override
  @JsonKey()
  final bool calleS0;
  // sensor_0   (nivel 0%)
  @override
  @JsonKey()
  final bool calleS50;
  // sensor_50  (nivel 50%)
  @override
  @JsonKey()
  final bool calleS100;
  // sensor_100 (nivel 100%)
  // —— Reed switches individuales Tanque Lluvia (IDs 11–13) ——
  @override
  @JsonKey()
  final bool lluviaS0;
  // sensor_0   (nivel 0%)
  @override
  @JsonKey()
  final bool lluviaS50;
  // sensor_50  (nivel 50%)
  @override
  @JsonKey()
  final bool lluviaS100;
  // sensor_100 (nivel 100%)
  @override
  @JsonKey()
  final String activeSource;

  /// Falla detectada actualmente por el motor de reglas.
  /// '' = sin falla. Posibles valores:
  /// 'rotura_tuberia_calle' | 'rotura_tuberia_lluvia'
  /// 'fuga_detectada' | 'presion_critica_alta'
  /// 'sensor_inconsistente_calle' | 'sensor_inconsistente_lluvia'
  /// 'agua_turbia_activa' | 'sin_fuente_disponible' | 'failover_automatico'
  @override
  @JsonKey()
  final String detectedFault;

  /// Última acción autónoma ejecutada (texto para el log de eventos).
  @override
  @JsonKey()
  final String autoActionLog;

  /// True cuando el sistema está operando en la fuente de respaldo
  /// por un failover automático (no por elección manual del usuario).
  @override
  @JsonKey()
  final bool failoverActive;

  /// True solo cuando el update viene de `agua_iot/notificaciones`.
  @override
  @JsonKey()
  final bool fromBridgeNotification;

  /// Alertas de tanque vacío disparadas por el bridge.
  @override
  @JsonKey()
  final bool tanqueCalleVacio;
  @override
  @JsonKey()
  final bool tanqueLluviaVacio;
  // ── Hardware Health Status (Reglas 8-13) ──────────────────────────────
  // true = sensor enviando datos correctamente
  /// Regla 8: Sensor de presión online (publica datos < 60s).
  @override
  @JsonKey()
  final bool sensorPresionOnline;

  /// Regla 8: Sensor de flujo online (publica datos < 60s).
  @override
  @JsonKey()
  final bool sensorFlujoOnline;

  /// Regla 8: Sensores de nivel de tanques online.
  @override
  @JsonKey()
  final bool sensoresNivelOnline;

  /// Regla 11: ESP32 de control (actuadores) tiene heartbeat reciente.
  @override
  @JsonKey()
  final bool esp32ControlOnline;

  /// Regla 9: Relé no responde a comando enviado.
  @override
  @JsonKey()
  final bool releAtascado;

  /// Regla 10: Motor sobrecargado — presión subió muy rápido.
  @override
  @JsonKey()
  final bool motorSobrecargado;

  /// Regla 12: Sensor de flujo reporta 0.00 exacto por mucho tiempo
  /// (posible tapón en el sensor, no rotura de tubo).
  @override
  @JsonKey()
  final bool sensorFlujoAtascado;

  /// Regla 13: Sensor de presión reporta 0.00 exacto por mucho tiempo
  /// (posible cable ADC desconectado, no presión real baja).
  @override
  @JsonKey()
  final bool sensorPresionAtascado;

  @override
  String toString() {
    return 'WaterSystemState(rainTankLevel: $rainTankLevel, streetTankLevel: $streetTankLevel, flowRate: $flowRate, streetPressure: $streetPressure, turbidity: $turbidity, isPumpActive: $isPumpActive, isSolenoidOpen: $isSolenoidOpen, isBombaCalleActive: $isBombaCalleActive, isSolenoideCalleOpen: $isSolenoideCalleOpen, isBombaLluviaActive: $isBombaLluviaActive, isSoleLluviaOpen: $isSoleLluviaOpen, calleS0: $calleS0, calleS50: $calleS50, calleS100: $calleS100, lluviaS0: $lluviaS0, lluviaS50: $lluviaS50, lluviaS100: $lluviaS100, activeSource: $activeSource, detectedFault: $detectedFault, autoActionLog: $autoActionLog, failoverActive: $failoverActive, fromBridgeNotification: $fromBridgeNotification, tanqueCalleVacio: $tanqueCalleVacio, tanqueLluviaVacio: $tanqueLluviaVacio, sensorPresionOnline: $sensorPresionOnline, sensorFlujoOnline: $sensorFlujoOnline, sensoresNivelOnline: $sensoresNivelOnline, esp32ControlOnline: $esp32ControlOnline, releAtascado: $releAtascado, motorSobrecargado: $motorSobrecargado, sensorFlujoAtascado: $sensorFlujoAtascado, sensorPresionAtascado: $sensorPresionAtascado)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WaterSystemStateImpl &&
            (identical(other.rainTankLevel, rainTankLevel) ||
                other.rainTankLevel == rainTankLevel) &&
            (identical(other.streetTankLevel, streetTankLevel) ||
                other.streetTankLevel == streetTankLevel) &&
            (identical(other.flowRate, flowRate) ||
                other.flowRate == flowRate) &&
            (identical(other.streetPressure, streetPressure) ||
                other.streetPressure == streetPressure) &&
            (identical(other.turbidity, turbidity) ||
                other.turbidity == turbidity) &&
            (identical(other.isPumpActive, isPumpActive) ||
                other.isPumpActive == isPumpActive) &&
            (identical(other.isSolenoidOpen, isSolenoidOpen) ||
                other.isSolenoidOpen == isSolenoidOpen) &&
            (identical(other.isBombaCalleActive, isBombaCalleActive) ||
                other.isBombaCalleActive == isBombaCalleActive) &&
            (identical(other.isSolenoideCalleOpen, isSolenoideCalleOpen) ||
                other.isSolenoideCalleOpen == isSolenoideCalleOpen) &&
            (identical(other.isBombaLluviaActive, isBombaLluviaActive) ||
                other.isBombaLluviaActive == isBombaLluviaActive) &&
            (identical(other.isSoleLluviaOpen, isSoleLluviaOpen) ||
                other.isSoleLluviaOpen == isSoleLluviaOpen) &&
            (identical(other.calleS0, calleS0) || other.calleS0 == calleS0) &&
            (identical(other.calleS50, calleS50) ||
                other.calleS50 == calleS50) &&
            (identical(other.calleS100, calleS100) ||
                other.calleS100 == calleS100) &&
            (identical(other.lluviaS0, lluviaS0) ||
                other.lluviaS0 == lluviaS0) &&
            (identical(other.lluviaS50, lluviaS50) ||
                other.lluviaS50 == lluviaS50) &&
            (identical(other.lluviaS100, lluviaS100) ||
                other.lluviaS100 == lluviaS100) &&
            (identical(other.activeSource, activeSource) ||
                other.activeSource == activeSource) &&
            (identical(other.detectedFault, detectedFault) ||
                other.detectedFault == detectedFault) &&
            (identical(other.autoActionLog, autoActionLog) ||
                other.autoActionLog == autoActionLog) &&
            (identical(other.failoverActive, failoverActive) ||
                other.failoverActive == failoverActive) &&
            (identical(other.fromBridgeNotification, fromBridgeNotification) ||
                other.fromBridgeNotification == fromBridgeNotification) &&
            (identical(other.tanqueCalleVacio, tanqueCalleVacio) ||
                other.tanqueCalleVacio == tanqueCalleVacio) &&
            (identical(other.tanqueLluviaVacio, tanqueLluviaVacio) ||
                other.tanqueLluviaVacio == tanqueLluviaVacio) &&
            (identical(other.sensorPresionOnline, sensorPresionOnline) ||
                other.sensorPresionOnline == sensorPresionOnline) &&
            (identical(other.sensorFlujoOnline, sensorFlujoOnline) ||
                other.sensorFlujoOnline == sensorFlujoOnline) &&
            (identical(other.sensoresNivelOnline, sensoresNivelOnline) ||
                other.sensoresNivelOnline == sensoresNivelOnline) &&
            (identical(other.esp32ControlOnline, esp32ControlOnline) ||
                other.esp32ControlOnline == esp32ControlOnline) &&
            (identical(other.releAtascado, releAtascado) ||
                other.releAtascado == releAtascado) &&
            (identical(other.motorSobrecargado, motorSobrecargado) ||
                other.motorSobrecargado == motorSobrecargado) &&
            (identical(other.sensorFlujoAtascado, sensorFlujoAtascado) ||
                other.sensorFlujoAtascado == sensorFlujoAtascado) &&
            (identical(other.sensorPresionAtascado, sensorPresionAtascado) ||
                other.sensorPresionAtascado == sensorPresionAtascado));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    rainTankLevel,
    streetTankLevel,
    flowRate,
    streetPressure,
    turbidity,
    isPumpActive,
    isSolenoidOpen,
    isBombaCalleActive,
    isSolenoideCalleOpen,
    isBombaLluviaActive,
    isSoleLluviaOpen,
    calleS0,
    calleS50,
    calleS100,
    lluviaS0,
    lluviaS50,
    lluviaS100,
    activeSource,
    detectedFault,
    autoActionLog,
    failoverActive,
    fromBridgeNotification,
    tanqueCalleVacio,
    tanqueLluviaVacio,
    sensorPresionOnline,
    sensorFlujoOnline,
    sensoresNivelOnline,
    esp32ControlOnline,
    releAtascado,
    motorSobrecargado,
    sensorFlujoAtascado,
    sensorPresionAtascado,
  ]);

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WaterSystemStateImplCopyWith<_$WaterSystemStateImpl> get copyWith =>
      __$$WaterSystemStateImplCopyWithImpl<_$WaterSystemStateImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$WaterSystemStateImplToJson(this);
  }
}

abstract class _WaterSystemState implements WaterSystemState {
  const factory _WaterSystemState({
    final double rainTankLevel,
    final double streetTankLevel,
    final double flowRate,
    final double streetPressure,
    final double turbidity,
    final bool isPumpActive,
    final bool isSolenoidOpen,
    final bool isBombaCalleActive,
    final bool isSolenoideCalleOpen,
    final bool isBombaLluviaActive,
    final bool isSoleLluviaOpen,
    final bool calleS0,
    final bool calleS50,
    final bool calleS100,
    final bool lluviaS0,
    final bool lluviaS50,
    final bool lluviaS100,
    final String activeSource,
    final String detectedFault,
    final String autoActionLog,
    final bool failoverActive,
    final bool fromBridgeNotification,
    final bool tanqueCalleVacio,
    final bool tanqueLluviaVacio,
    final bool sensorPresionOnline,
    final bool sensorFlujoOnline,
    final bool sensoresNivelOnline,
    final bool esp32ControlOnline,
    final bool releAtascado,
    final bool motorSobrecargado,
    final bool sensorFlujoAtascado,
    final bool sensorPresionAtascado,
  }) = _$WaterSystemStateImpl;

  factory _WaterSystemState.fromJson(Map<String, dynamic> json) =
      _$WaterSystemStateImpl.fromJson;

  @override
  double get rainTankLevel;
  @override
  double get streetTankLevel;
  @override
  double get flowRate;
  @override
  double get streetPressure;
  @override
  double get turbidity; // BombaButton standalone — agua_iot/actuadores/bomba (NO comparte con Fuentes)
  @override
  bool get isPumpActive;
  @override
  bool get isSolenoidOpen; // Fuente Calle — bomba_calle + solenoide_calle
  @override
  bool get isBombaCalleActive;
  @override
  bool get isSolenoideCalleOpen; // Fuente Lluvia — bomba_lluvia + solenoide_lluvia
  @override
  bool get isBombaLluviaActive;
  @override
  bool get isSoleLluviaOpen; // —— Reed switches individuales Tanque Calle (IDs 8–10) ——
  // true = sensor detecta agua (LOW en el ESP32)
  @override
  bool get calleS0; // sensor_0   (nivel 0%)
  @override
  bool get calleS50; // sensor_50  (nivel 50%)
  @override
  bool get calleS100; // sensor_100 (nivel 100%)
  // —— Reed switches individuales Tanque Lluvia (IDs 11–13) ——
  @override
  bool get lluviaS0; // sensor_0   (nivel 0%)
  @override
  bool get lluviaS50; // sensor_50  (nivel 50%)
  @override
  bool get lluviaS100; // sensor_100 (nivel 100%)
  @override
  String get activeSource;

  /// Falla detectada actualmente por el motor de reglas.
  /// '' = sin falla. Posibles valores:
  /// 'rotura_tuberia_calle' | 'rotura_tuberia_lluvia'
  /// 'fuga_detectada' | 'presion_critica_alta'
  /// 'sensor_inconsistente_calle' | 'sensor_inconsistente_lluvia'
  /// 'agua_turbia_activa' | 'sin_fuente_disponible' | 'failover_automatico'
  @override
  String get detectedFault;

  /// Última acción autónoma ejecutada (texto para el log de eventos).
  @override
  String get autoActionLog;

  /// True cuando el sistema está operando en la fuente de respaldo
  /// por un failover automático (no por elección manual del usuario).
  @override
  bool get failoverActive;

  /// True solo cuando el update viene de `agua_iot/notificaciones`.
  @override
  bool get fromBridgeNotification;

  /// Alertas de tanque vacío disparadas por el bridge.
  @override
  bool get tanqueCalleVacio;
  @override
  bool get tanqueLluviaVacio; // ── Hardware Health Status (Reglas 8-13) ──────────────────────────────
  // true = sensor enviando datos correctamente
  /// Regla 8: Sensor de presión online (publica datos < 60s).
  @override
  bool get sensorPresionOnline;

  /// Regla 8: Sensor de flujo online (publica datos < 60s).
  @override
  bool get sensorFlujoOnline;

  /// Regla 8: Sensores de nivel de tanques online.
  @override
  bool get sensoresNivelOnline;

  /// Regla 11: ESP32 de control (actuadores) tiene heartbeat reciente.
  @override
  bool get esp32ControlOnline;

  /// Regla 9: Relé no responde a comando enviado.
  @override
  bool get releAtascado;

  /// Regla 10: Motor sobrecargado — presión subió muy rápido.
  @override
  bool get motorSobrecargado;

  /// Regla 12: Sensor de flujo reporta 0.00 exacto por mucho tiempo
  /// (posible tapón en el sensor, no rotura de tubo).
  @override
  bool get sensorFlujoAtascado;

  /// Regla 13: Sensor de presión reporta 0.00 exacto por mucho tiempo
  /// (posible cable ADC desconectado, no presión real baja).
  @override
  bool get sensorPresionAtascado;

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaterSystemStateImplCopyWith<_$WaterSystemStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
