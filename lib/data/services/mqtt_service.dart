import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/repositories/water_data_repository.dart';

/// Implementación de [WaterDataRepository] que se conecta al broker
/// privado HiveMQ Cloud via MQTT/TLS y parsea los topics agua_iot/*.
class MqttWaterRepository implements WaterDataRepository {
  MqttServerClient? _client;
  final StreamController<WaterSystemState> _stateController =
      StreamController.broadcast();
  WaterSystemState _currentState = const WaterSystemState();
  bool _isInitialized = false;

  @override
  Stream<WaterSystemState> get stateStream => _stateController.stream;

  // Credenciales del broker privado HiveMQ Cloud (mismo que backend_iot/.env)
  static const String _broker =
      '5ef81785739742498a262dacb92759fd.s1.eu.hivemq.cloud';
  static const int _port = 8883;
  static const String _username = 'agua_iot';
  static const String _password = 'grupoAlamScar123.';

  // Topics alineados con backend_iot/simulador.js (6 sensores)
  static const String _topicPresion1 = 'agua_iot/sensores_presion/1';
  static const String _topicPresion2 = 'agua_iot/sensores_presion/2';
  static const String _topicNivelLluvia = 'agua_iot/nivel/lectura';
  static const String _topicNivelCalle = 'agua_iot/nivel/lectura_2';
  static const String _topicTurbidez = 'agua_iot/calidad/turbidez';
  static const String _topicBomba = 'agua_iot/actuadores/bomba';
  static const String _topicSolenoide = 'agua_iot/actuadores/solenoide';

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // MQTT con TLS no funciona en Flutter Web
    if (kIsWeb) {
      debugPrint(
          '⚠️ MQTT: Plataforma web detectada. Usa el modo simulación local.');
      return;
    }

    final client = MqttServerClient.withPort(_broker, '', _port);
    client.secure = true;
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;
    client.onAutoReconnect = () => debugPrint('⚠️ MQTT reconectando...');
    client.onAutoReconnected = () => debugPrint('✅ MQTT reconectado');

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
            'flutter_wss_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;

    try {
      debugPrint('⏳ Conectando a MQTT: $_broker:$_port...');
      await client.connect(_username, _password);
    } catch (e) {
      debugPrint('❌ Excepción MQTT: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('✅ MQTT Conectado a HiveMQ Cloud');
      _client = client;
      _isInitialized = true;
      _subscribeTopics();
      client.updates!.listen(_onMessage);
    } else {
      debugPrint('❌ Conexión MQTT fallida: ${client.connectionStatus}');
      client.disconnect();
    }
  }

  void _subscribeTopics() {
    final topics = [
      _topicPresion1,
      _topicPresion2,
      _topicNivelLluvia,
      _topicNivelCalle,
      _topicTurbidez,
      _topicBomba,
      _topicSolenoide,
    ];
    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
    debugPrint('📡 Suscrito a ${topics.length} topics');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty) return;

    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String topic = c[0].topic;
    final String payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    final double? value = double.tryParse(payload);
    if (value == null) {
      debugPrint('⚠️ Valor no numérico en $topic: $payload');
      return;
    }

    // Actualizar estado acumulativo según topic
    switch (topic) {
      case _topicPresion1:
        _currentState = _currentState.copyWith(streetPressure: value);
        break;
      case _topicPresion2:
        // Segundo sensor de presión — almacenamos en flowRate por compatibilidad
        _currentState = _currentState.copyWith(flowRate: value);
        break;
      case _topicNivelLluvia:
        _currentState = _currentState.copyWith(rainTankLevel: value);
        break;
      case _topicNivelCalle:
        _currentState = _currentState.copyWith(streetTankLevel: value);
        break;
      case _topicTurbidez:
        _currentState = _currentState.copyWith(turbidity: value);
        break;
      case _topicBomba:
        _currentState = _currentState.copyWith(isPumpActive: value > 0.5);
        break;
      case _topicSolenoide:
        _currentState = _currentState.copyWith(isSolenoidOpen: value > 0.5);
        break;
      default:
        return;
    }

    _stateController.add(_currentState);
  }

  @override
  void sendCommand(String command, String value) {
    if (!_isInitialized || _client == null) {
      debugPrint('⚠️ MQTT no conectado, comando ignorado: $command=$value');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(value);
    _client!.publishMessage(
      'agua_iot/comandos/$command',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  @override
  void dispose() {
    _stateController.close();
    if (_isInitialized && _client != null) {
      _client!.disconnect();
      _isInitialized = false;
    }
  }
}

final mqttRepositoryProvider = Provider<WaterDataRepository>((ref) {
  final repo = MqttWaterRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
