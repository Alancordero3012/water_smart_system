import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Identificadores de reglas inteligentes ────────────────────────────────────
// Usados para habilitar/deshabilitar reglas individualmente desde Settings.
const kAllSmartRules = [
  'sensor_inconsistente',
  'fuga_agua',
  'presion_alta',
  'rotura_tuberia',
  'presion_baja',
  'restaurar_fuente',
  'tendencia_presion',
  'correlacion_nivel_flujo',
];

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  // ── Claves existentes ─────────────────────────────────────────────────────
  static const _keyReserve    = 'minReserveThreshold';
  static const _keyPriority   = 'prioritySource'; // 'rain' or 'street'
  static const _keyPredictive = 'predictiveSaving';

  // ── Claves nuevas ─────────────────────────────────────────────────────────
  static const _keyTankCapacity   = 'tankCapacityLiters';
  static const _keyWeatherLat     = 'weatherLatitude';
  static const _keyWeatherLon     = 'weatherLongitude';
  static const _keyEnabledRules   = 'enabledRulesJson'; // JSON string

  // ── Getters existentes ────────────────────────────────────────────────────

  double get minReserveThreshold    => _prefs.getDouble(_keyReserve) ?? 20.0;
  String get prioritySource         => _prefs.getString(_keyPriority) ?? 'rain';
  bool   get isPredictiveSavingEnabled => _prefs.getBool(_keyPredictive) ?? false;

  // ── Getters nuevos ────────────────────────────────────────────────────────

  /// Capacidad real del tanque en litros (usada para calcular ahorro real).
  double get tankCapacityLiters => _prefs.getDouble(_keyTankCapacity) ?? 200.0;

  /// Latitud para consulta de clima (Open-Meteo).
  double get weatherLatitude  => _prefs.getDouble(_keyWeatherLat) ?? 10.48;

  /// Longitud para consulta de clima (Open-Meteo).
  double get weatherLongitude => _prefs.getDouble(_keyWeatherLon) ?? -66.90;

  /// Devuelve true si la regla está habilitada (por defecto todas activas).
  bool isRuleEnabled(String ruleKey) {
    final stored = _prefs.getString(_keyEnabledRules);
    if (stored == null) return true; // default: todas activas
    try {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      return map[ruleKey] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Devuelve el mapa completo de reglas habilitadas.
  Map<String, bool> get enabledRulesMap {
    final stored = _prefs.getString(_keyEnabledRules);
    final base   = {for (final r in kAllSmartRules) r: true};
    if (stored == null) return base;
    try {
      final map = jsonDecode(stored) as Map<String, dynamic>;
      return base.map((k, v) => MapEntry(k, map[k] as bool? ?? v));
    } catch (_) {
      return base;
    }
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  Future<void> setMinReserveThreshold(double value) async =>
      _prefs.setDouble(_keyReserve, value);

  Future<void> setPrioritySource(String value) async =>
      _prefs.setString(_keyPriority, value);

  Future<void> setPredictiveSaving(bool value) async =>
      _prefs.setBool(_keyPredictive, value);

  Future<void> setTankCapacityLiters(double value) async =>
      _prefs.setDouble(_keyTankCapacity, value);

  Future<void> setWeatherCoordinates(double lat, double lon) async {
    await _prefs.setDouble(_keyWeatherLat, lat);
    await _prefs.setDouble(_keyWeatherLon, lon);
  }

  Future<void> setRuleEnabled(String ruleKey, bool enabled) async {
    final current = enabledRulesMap;
    current[ruleKey] = enabled;
    await _prefs.setString(_keyEnabledRules, jsonEncode(current));
  }

  Future<void> saveEnabledRules(Map<String, bool> rules) async {
    await _prefs.setString(_keyEnabledRules, jsonEncode(rules));
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});
