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
  double get turbidity => throw _privateConstructorUsedError;
  bool get isPumpActive => throw _privateConstructorUsedError;
  bool get isSolenoidOpen => throw _privateConstructorUsedError;
  String get activeSource => throw _privateConstructorUsedError;

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
    String activeSource,
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
    Object? activeSource = null,
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
            activeSource: null == activeSource
                ? _value.activeSource
                : activeSource // ignore: cast_nullable_to_non_nullable
                      as String,
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
    String activeSource,
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
    Object? activeSource = null,
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
        activeSource: null == activeSource
            ? _value.activeSource
            : activeSource // ignore: cast_nullable_to_non_nullable
                  as String,
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
    this.activeSource = 'lluvia',
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
  @override
  @JsonKey()
  final bool isPumpActive;
  @override
  @JsonKey()
  final bool isSolenoidOpen;
  @override
  @JsonKey()
  final String activeSource;

  @override
  String toString() {
    return 'WaterSystemState(rainTankLevel: $rainTankLevel, streetTankLevel: $streetTankLevel, flowRate: $flowRate, streetPressure: $streetPressure, turbidity: $turbidity, isPumpActive: $isPumpActive, isSolenoidOpen: $isSolenoidOpen, activeSource: $activeSource)';
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
            (identical(other.activeSource, activeSource) ||
                other.activeSource == activeSource));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    rainTankLevel,
    streetTankLevel,
    flowRate,
    streetPressure,
    turbidity,
    isPumpActive,
    isSolenoidOpen,
    activeSource,
  );

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
    final String activeSource,
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
  double get turbidity;
  @override
  bool get isPumpActive;
  @override
  bool get isSolenoidOpen;
  @override
  String get activeSource;

  /// Create a copy of WaterSystemState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaterSystemStateImplCopyWith<_$WaterSystemStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
