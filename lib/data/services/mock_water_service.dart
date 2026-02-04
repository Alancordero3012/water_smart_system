import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';

class MockWaterService {
  final StreamController<WaterSystemState> _controller =
      StreamController.broadcast();
  Timer? _timer;
  final Random _random = Random();
  WaterSystemState _currentState = const WaterSystemState();

  Stream<WaterSystemState> get stateStream => _controller.stream;

  void startSimulation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Simulate fluctuating levels
      final newRainLevel =
          (_currentState.rainTankLevel + (_random.nextDouble() * 2 - 1))
              .clamp(0.0, 100.0);
      final newStreetLevel =
          (_currentState.streetTankLevel + (_random.nextDouble() * 2 - 1))
              .clamp(0.0, 100.0);
      final newPressure =
          (_currentState.streetPressure + (_random.nextDouble() * 5 - 2.5))
              .clamp(0.0, 100.0);

      _currentState = _currentState.copyWith(
        rainTankLevel: newRainLevel,
        streetTankLevel: newStreetLevel,
        streetPressure: newPressure,
        flowRate: (_random.nextDouble() * 10).clamp(0.0, 10.0),
        turbidity: (_random.nextDouble() * 10),
      );

      _controller.add(_currentState);
    });
  }

  void stopSimulation() {
    _timer?.cancel();
  }
}

final mockWaterServiceProvider = Provider((ref) => MockWaterService());
