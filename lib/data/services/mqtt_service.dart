import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';
import '../../domain/repositories/water_data_repository.dart';
import 'mqtt_client_factory.dart'; // Picks MqttServerClient or MqttBrowserClient

/// MQTT repository that works on all platforms:
///   - Desktop / Mobile : TLS/TCP via port 8883 (MqttServerClient)
///   - Flutter Web      : WSS via port 8884   (MqttBrowserClient)
class MqttWaterRepository implements WaterDataRepository {
  MqttClient? _client;
  final StreamController<WaterSystemState> _stateController =
      StreamController.broadcast();
  WaterSystemState _currentState = const WaterSystemState();
  bool _isInitialized = false;

  @override
  Stream<WaterSystemState> get stateStream => _stateController.stream;

  // ── Broker credentials ────────────────────────────────────────────────
  static const String _broker =
      '5ef81785739742498a262dacb92759fd.s1.eu.hivemq.cloud';
  static const int _portNative = 8883; // TLS/TCP  — desktop/mobile
  static const int _portWeb    = 8884; // WSS       — browser
  static const String _username = 'agua_iot';
  static const String _password = 'grupoAlamScar123.';

  // ── Topics ────────────────────────────────────────────────────────────
  static const String _topicPresion1       = 'agua_iot/sensores_presion/1';
  static const String _topicPresion2       = 'agua_iot/sensores_presion/2';
  static const String _topicNivelLluvia    = 'agua_iot/nivel/lectura';
  static const String _topicNivelCalle     = 'agua_iot/nivel/lectura_2';
  static const String _topicTurbidez       = 'agua_iot/calidad/turbidez';
  static const String _topicBomba          = 'agua_iot/actuadores/bomba';
  static const String _topicSolenoide      = 'agua_iot/actuadores/solenoide';
  static const String _topicNotificaciones = 'agua_iot/notificaciones';

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    final port = kIsWeb ? _portWeb : _portNative;
    final clientId = 'flutter_wss_${DateTime.now().millisecondsSinceEpoch}';

    debugPrint('⏳ MQTT: Iniciando conexión en ${kIsWeb ? "Web (WSS:$port)" : "Desktop (TLS:$port)"}...');
    debugPrint('   Broker : $_broker');
    debugPrint('   Puerto : $port');

    // Factory picks the correct client for the platform at compile time.
    final client = createMqttClient(_broker, clientId, port);
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;
    client.onAutoReconnect  = () => debugPrint('⚠️ MQTT reconectando...');
    client.onAutoReconnected = () => debugPrint('✅ MQTT reconectado');

    // Clean CONNECT — no will message to avoid broker rejection.
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    try {
      debugPrint('⏳ MQTT: Enviando CONNECT al broker...');
      await client.connect(_username, _password);
    } catch (e) {
      debugPrint('❌ MQTT excepción al conectar: $e');
      client.disconnect();
      _stateController.addError(
        'MQTT no pudo conectar:\n$e\n\n'
        'Asegúrate de que index.js y simulador.js están corriendo.',
      );
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('✅ MQTT conectado a HiveMQ Cloud (${kIsWeb ? "WSS" : "TLS"})');
      _client = client;
      _isInitialized = true;
      _subscribeTopics();
      client.updates?.listen(_onMessage);
    } else {
      debugPrint('❌ MQTT conexión fallida: ${client.connectionStatus}');
      client.disconnect();
      _stateController.addError(
        'MQTT no se pudo conectar. Estado: ${client.connectionStatus?.state}',
      );
    }
  }

  void _subscribeTopics() {
    final topics = [
      _topicPresion1, _topicPresion2,
      _topicNivelLluvia, _topicNivelCalle,
      _topicTurbidez, _topicBomba, _topicSolenoide,
      _topicNotificaciones,
    ];
    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
    debugPrint('📡 MQTT suscrito a ${topics.length} topics');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    if (c == null || c.isEmpty) return;

    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String topic   = c[0].topic;
    final String payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    if (topic == _topicNotificaciones) {
      _handleBridgeNotification(payload);
      return;
    }

    final double? value = double.tryParse(payload);
    if (value == null) return;

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

  void _handleBridgeNotification(String payload) {
    try {
      final data  = jsonDecode(payload) as Map<String, dynamic>;
      final type  = data['type'] as String?;
      final value = (data['value'] as num?)?.toDouble();
      if (type == null || value == null) return;

      debugPrint('🔔 Notificación del bridge: $type = $value');
      WaterSystemState notifState =
          _currentState.copyWith(fromBridgeNotification: true);

      switch (type) {
        case 'turbidez_critica': notifState = notifState.copyWith(turbidity: value); break;
        case 'baja_presion':     notifState = notifState.copyWith(streetPressure: value); break;
        default: return;
      }

      _currentState = notifState;
      _stateController.add(_currentState);
    } catch (e) {
      debugPrint('⚠️ Error parseando notificación del bridge: $e');
    }
  }

  @override
  void sendCommand(String command, String value) {
    if (!_isInitialized || _client == null) {
      debugPrint('⚠️ MQTT no conectado, comando ignorado: $command=$value');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(value);
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
