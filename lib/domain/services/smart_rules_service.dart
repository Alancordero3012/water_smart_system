import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/preferences_service.dart';
import '../models/water_system_state.dart';

class SmartRulesService {
  final PreferencesService _preferences;

  SmartRulesService(this._preferences);

  // Configurable thresholds
  static const double minPressure = 10.0; // PSI
  static const double maxTurbidity = 50.0; // NTU

  WaterSystemState evaluateRules(WaterSystemState currentState) {
    String targetSource = currentState.activeSource;
    bool pumpState = currentState.isPumpActive;

    final double minSafeLevel = _preferences.minReserveThreshold;
    final String userPriority = _preferences.prioritySource;
    final bool predictiveSaving = _preferences.isPredictiveSavingEnabled;

    // 1. Protection Rules (Highest Priority)
    if (currentState.streetPressure < minPressure) {
      // If street pressure is low, we cannot rely on it directly.
    }

    if (currentState.turbidity > maxTurbidity) {
      // Dirty water!
    }

    // 2. Supply Rules
    // Custom logic: prefer rain if available > minSafeLevel AND user prefers rain

    bool useRain = false;

    if (currentState.rainTankLevel > minSafeLevel) {
      if (userPriority == 'rain') {
        useRain = true;
      } else if (predictiveSaving && currentState.rainTankLevel > 10) {
        // Override: If rain is predicted/saving enabled, try to use rain tank more aggressively
        // (simulating waiting for refill) or conversely, if we expect rain,
        // we might want to EMPTY the tank to make room?
        // REQUIREMENT Says: "Posponer Riego".
        // Let's interpret: If predictive saving is ON, we prefer Rain source to save City water.
        useRain = true;
      }
    }

    if (useRain) {
      targetSource = 'lluvia';
    } else {
      targetSource = 'calle';
    }

    // 3. Actuator Control

    return currentState.copyWith(
      activeSource: targetSource,
      isPumpActive: pumpState,
    );
  }
}

final smartRulesProvider = Provider((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return SmartRulesService(prefs);
});
