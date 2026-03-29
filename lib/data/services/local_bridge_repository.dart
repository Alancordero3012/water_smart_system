import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/repositories/water_data_repository.dart';

/// Connects to the local Node.js bridge WebSocket server at ws://localhost:3001.
///
/// The bridge (index.js) forwards every MQTT message it receives from HiveMQ
/// as a JSON object: `{ "topic": "agua_iot/...", "value": 12.34 }`.
///
/// Used ONLY on Flutter Web where direct HiveMQ WebSocket connections are blocked
/// by origin policy. On desktop/mobile use [MqttWaterRepository] instead.
class LocalBridgeRepository implements WaterDataRepository {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

  final StreamController<WaterSystemState> _stateController =
      StreamController.broadcast();
  WaterSystemState _currentState = const WaterSystemState();
  bool _isInitialized = false;

  static const String _wsUrl = 'ws://localhost:3001';

  @override
  Stream<WaterSystemState> get stateStream => _stateController.stream;

  // Topic → field mapping (must match what index.js broadcasts)
  static const String _topicPresion1    = 'agua_iot/sensores_presion/1';
  static const String _topicPresion2    = 'agua_iot/sensores_presion/2';
  static const String _topicNivelLluvia = 'agua_iot/nivel/lectura';
  static const String _topicNivelCalle  = 'agua_iot/nivel/lectura_2';
  static const String _topicTurbidez    = 'agua_iot/calidad/turbidez';
  static const String _topicBomba       = 'agua_iot/actuadores/bomba';
  static const String _topicSolenoide   = 'agua_iot/actuadores/solenoide';

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('⏳ LocalBridge: conectando a $_wsUrl ...');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      // Await the readyState handshake
      await _channel!.ready;
    } catch (e) {
      debugPrint('❌ LocalBridge: no se pudo conectar: $e');
      _stateController.addError(
        "Bridge Offline: Ejecuta 'node index.js' en tu terminal\n($e)",
      );
      return;
    }

    debugPrint('✅ LocalBridge: conectado a $_wsUrl');
    _isInitialized = true;

    _sub = _channel!.stream.listen(
      _onMessage,
      onError: (e) {
        debugPrint('❌ LocalBridge WS error: $e');
        _stateController.addError(
          "Bridge Offline: Ejecuta 'node index.js' en tu terminal\n($e)",
        );
        _isInitialized = false;
      },
      onDone: () {
        debugPrint('⚠️ LocalBridge: conexión cerrada. Reinicia index.js.');
        _isInitialized = false;
      },
    );
  }

  void _onMessage(dynamic raw) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    // Connection confirmation handshake — ignore
    if (data['type'] == 'connected') {
      debugPrint('✅ LocalBridge: bridge WS handshake OK');
      return;
    }

    final String? topic = data['topic'] as String?;
    final double? value = (data['value'] as num?)?.toDouble();
    if (topic == null || value == null) return;

    WaterSystemState next =
        _currentState.copyWith(fromBridgeNotification: false);

    switch (topic) {
      case _topicPresion1:    next = next.copyWith(streetPressure: value); break;
      case _topicPresion2:    next = next.copyWith(flowRate: value); break;
      case _topicNivelLluvia: next = next.copyWith(rainTankLevel: value); break;
      case _topicNivelCalle:  next = next.copyWith(streetTankLevel: value); break;
      case _topicTurbidez:    next = next.copyWith(turbidity: value); break;
      case _topicBomba:       next = next.copyWith(isPumpActive: value > 0.5); break;
      case _topicSolenoide:   next = next.copyWith(isSolenoidOpen: value > 0.5); break;
      default: return;
    }

    _currentState = next;
    _stateController.add(_currentState);
  }

  @override
  void sendCommand(String command, String value) {
    if (!_isInitialized || _channel == null) return;
    _channel!.sink.add(jsonEncode({'command': command, 'value': value}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _stateController.close();
    _isInitialized = false;
  }
}

final localBridgeRepositoryProvider = Provider<WaterDataRepository>((ref) {
  final repo = LocalBridgeRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
