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
  // Legacy (simulador.js)
  static const String _topicNivelLluvia    = 'agua_iot/nivel/lectura';
  static const String _topicNivelCalle     = 'agua_iot/nivel/lectura_2';
  // ESP32 hardware real — tanques con reed switches (nivel calculado)
  static const String _topicTanqueLluvia   = 'agua_iot/tanque_lluvia/nivel';
  static const String _topicTanqueCalle    = 'agua_iot/tanque_calle/nivel';
  // ESP32 hardware real — sensores individuales Tanque Calle (IDs 8-10)
  static const String _topicCalleS0        = 'agua_iot/tanque_calle/sensor_0';
  static const String _topicCalleS50       = 'agua_iot/tanque_calle/sensor_50';
  static const String _topicCalleS100      = 'agua_iot/tanque_calle/sensor_100';
  // ESP32 hardware real — sensores individuales Tanque Lluvia (IDs 11-13)
  static const String _topicLluviaS0       = 'agua_iot/tanque_lluvia/sensor_0';
  static const String _topicLluviaS50      = 'agua_iot/tanque_lluvia/sensor_50';
  static const String _topicLluviaS100     = 'agua_iot/tanque_lluvia/sensor_100';
  // ESP32 hardware real — presión ADC y flujo por pulsos
  static const String _topicPresionReal    = 'agua_iot/sensores/presion';
  static const String _topicFlujoReal      = 'agua_iot/sensores/flujo';
  static const String _topicTurbidez       = 'agua_iot/calidad/turbidez';
  // Actuadores — legacy
  static const String _topicBomba          = 'agua_iot/actuadores/bomba';
  static const String _topicSolenoide      = 'agua_iot/actuadores/solenoide';
  // Actuadores — ESP32_WaterSmart_Alan (hardware real)
  static const String _topicBombaCalle     = 'agua_iot/actuadores/bomba_calle';
  static const String _topicSolenoideCalle = 'agua_iot/actuadores/solenoide_calle';
  static const String _topicBombaLluvia    = 'agua_iot/actuadores/bomba_lluvia';
  static const String _topicSolenoideL     = 'agua_iot/actuadores/solenoide_lluvia';
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
      // Legacy (simulador)
      _topicNivelLluvia, _topicNivelCalle,
      // ESP32 hardware real — nivel calculado
      _topicTanqueLluvia, _topicTanqueCalle,
      // ESP32 hardware real — sensores individuales Calle
      _topicCalleS0, _topicCalleS50, _topicCalleS100,
      // ESP32 hardware real — sensores individuales Lluvia
      _topicLluviaS0, _topicLluviaS50, _topicLluviaS100,
      // ESP32 hardware real — presión y flujo
      _topicPresionReal, _topicFlujoReal,
      _topicTurbidez,
      // Actuadores legacy
      _topicBomba, _topicSolenoide,
      // Actuadores hardware real (Fuente 1 = calle, Fuente 2 = lluvia)
      _topicBombaCalle, _topicSolenoideCalle,
      _topicBombaLluvia, _topicSolenoideL,
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
      case _topicPresion1:
      case _topicPresionReal:  next = next.copyWith(streetPressure: value); break;
      case _topicPresion2:
      case _topicFlujoReal:    next = next.copyWith(flowRate: value);       break;
      // Legacy (simulador.js) y ESP32 hardware usan el mismo campo
      case _topicNivelLluvia:
      case _topicTanqueLluvia: next = next.copyWith(rainTankLevel: value);   break;
      case _topicNivelCalle:
      case _topicTanqueCalle:  next = next.copyWith(streetTankLevel: value); break;
      case _topicTurbidez:     next = next.copyWith(turbidity: value); break;
      // Reed switches individuales — Tanque Calle (1 = agua detectada, 0 = seco)
      case _topicCalleS0:   next = next.copyWith(calleS0:   value > 0.5); break;
      case _topicCalleS50:  next = next.copyWith(calleS50:  value > 0.5); break;
      case _topicCalleS100: next = next.copyWith(calleS100: value > 0.5); break;
      // Reed switches individuales — Tanque Lluvia
      case _topicLluviaS0:   next = next.copyWith(lluviaS0:   value > 0.5); break;
      case _topicLluviaS50:  next = next.copyWith(lluviaS50:  value > 0.5); break;
      case _topicLluviaS100: next = next.copyWith(lluviaS100: value > 0.5); break;
      // Actuadores: completamente desacoplados por tópico
      case _topicBomba:          next = next.copyWith(isPumpActive: value > 0.5); break;
      case _topicSolenoide:      next = next.copyWith(isSolenoidOpen: value > 0.5); break;
      case _topicBombaCalle:     next = next.copyWith(isBombaCalleActive: value > 0.5); break;
      case _topicSolenoideCalle: next = next.copyWith(isSolenoideCalleOpen: value > 0.5); break;
      case _topicBombaLluvia:    next = next.copyWith(isBombaLluviaActive: value > 0.5); break;
      case _topicSolenoideL:     next = next.copyWith(isSoleLluviaOpen: value > 0.5); break;
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
      if (type == null) return;

      debugPrint('🔔 Notificación del bridge: $type');
      WaterSystemState notifState =
          _currentState.copyWith(fromBridgeNotification: true);

      switch (type) {
        // ── Alertas numéricas de sensor ───────────────────────────────────
        case 'turbidez_critica':
          if (value != null) notifState = notifState.copyWith(turbidity: value);
          break;
        case 'baja_presion':
          if (value != null) notifState = notifState.copyWith(streetPressure: value);
          break;
        case 'tanque_calle_vacio':
          notifState = notifState.copyWith(tanqueCalleVacio: true);
          break;
        case 'tanque_lluvia_vacio':
          notifState = notifState.copyWith(tanqueLluviaVacio: true);
          break;

        // ── Regla 11: Estado ESP32 ────────────────────────────────────────
        case 'esp32_offline':
          final fuente = data['fuente'] as String? ?? '';
          notifState = notifState.copyWith(
            esp32ControlOnline: false,
            detectedFault: 'esp32_offline_$fuente',
          );
          break;
        case 'esp32_online':
          notifState = notifState.copyWith(
            esp32ControlOnline: true,
            detectedFault: '',
          );
          break;

        // ── Regla 1/3: Failover automático ───────────────────────────────
        case 'failover_automatico':
          final de = data['de'] as String? ?? '';
          final a  = data['a']  as String? ?? '';
          notifState = notifState.copyWith(
            activeSource  : a,
            failoverActive: true,
            detectedFault : 'failover_automatico',
            autoActionLog : '🔄 Failover automático: $de → $a',
          );
          break;

        // ── Regla 1: Rotura de tubería detectada ──────────────────────────
        case 'rotura_tuberia':
          final fuente = data['fuente'] as String? ?? '';
          notifState = notifState.copyWith(
            detectedFault: 'rotura_tuberia_$fuente',
          );
          break;

        // ── Regla 2: Fuga detectada ───────────────────────────────────────
        case 'fuga_detectada':
          notifState = notifState.copyWith(detectedFault: 'fuga_detectada');
          break;

        // ── Regla 7: Agua turbia activa ───────────────────────────────────
        case 'agua_turbia_activa':
          notifState = notifState.copyWith(detectedFault: 'agua_turbia_activa');
          break;

        // ── Regla 4: Presión crítica alta ─────────────────────────────────
        case 'presion_critica_alta':
          final fuente = data['fuente'] as String? ?? '';
          notifState = notifState.copyWith(
            detectedFault: 'presion_critica_alta_$fuente',
          );
          break;

        // ── Sin fuente disponible ─────────────────────────────────────────
        case 'sin_fuente_disponible':
          notifState = notifState.copyWith(
            detectedFault: 'sin_fuente_disponible',
            autoActionLog: '🚨 Ambas fuentes no disponibles — sistema detenido',
          );
          break;

        default:
          debugPrint('ℹ️ Notificación no manejada en Flutter: $type');
          return;
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

    // Mapa: nombre lógico del comando → tópico MQTT del actuador
    const commandTopicMap = {
      // ESP32_Bomba_Unica (standalone)
      'bomba'            : 'agua_iot/actuadores/bomba',
      'solenoide'        : 'agua_iot/actuadores/solenoide',
      // ESP32_WaterSmart_Alan (Fuente 1 = calle | Fuente 2 = lluvia)
      'bomba_calle'      : 'agua_iot/actuadores/bomba_calle',
      'solenoide_calle'  : 'agua_iot/actuadores/solenoide_calle',
      'bomba_lluvia'     : 'agua_iot/actuadores/bomba_lluvia',
      'solenoide_lluvia' : 'agua_iot/actuadores/solenoide_lluvia',
    };

    final topic = commandTopicMap[command] ?? 'agua_iot/comandos/$command';
    debugPrint('📤 MQTT sendCommand → $topic = $value');

    final builder = MqttClientPayloadBuilder()..addString(value);
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: true,
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
