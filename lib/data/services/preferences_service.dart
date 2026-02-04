import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static const _keyReserve = 'minReserveThreshold';
  static const _keyPriority = 'prioritySource'; // 'rain' or 'street'
  static const _keyPredictive = 'predictiveSaving';

  // Default: 20% reserve
  double get minReserveThreshold => _prefs.getDouble(_keyReserve) ?? 20.0;

  // Default: Prefer Rain
  String get prioritySource => _prefs.getString(_keyPriority) ?? 'rain';

  // Default: Disabled
  bool get isPredictiveSavingEnabled => _prefs.getBool(_keyPredictive) ?? false;

  Future<void> setMinReserveThreshold(double value) async {
    await _prefs.setDouble(_keyReserve, value);
  }

  Future<void> setPrioritySource(String value) async {
    await _prefs.setString(_keyPriority, value);
  }

  Future<void> setPredictiveSaving(bool value) async {
    await _prefs.setBool(_keyPredictive, value);
  }
}

// Validation: Providers
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize sharedPreferencesProvider in main.dart');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});
