import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/water_system_state.dart';

class MqttService {
  late MqttServerClient client;
  final StreamController<WaterSystemState> _stateController =
      StreamController.broadcast();

  Stream<WaterSystemState> get stateStream => _stateController.stream;

  Future<void> initialize() async {
    client = MqttServerClient.withPort(
      'broker.hivemq.com',
      'flutter_client',
      1883,
    );
    client.logging(on: false);
    client.keepAlivePeriod = 20;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_water_system')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('MQTT Client Connected');
      _subscribeTopics();
      client.updates!.listen(_onMessage);
    } else {
      debugPrint(
        'MQTT Client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      client.disconnect();
    }
  }

  void _subscribeTopics() {
    client.subscribe('water_system/sensors', MqttQos.atLeastOnce);
    client.subscribe('water_system/status', MqttQos.atLeastOnce);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
    final String pt = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    try {
      final jsonMap = json.decode(pt);
      // Assuming the ESP32 sends a partial or full JSON that matches our model
      // We might need to merge it with current state if it's partial,
      // but for now let's assume it sends the full state or we handle it in the provider.
      // _stateController.add(WaterSystemState.fromJson(jsonMap));

      // Temporary manual parsing if needed or directly fromJson
      final newState = WaterSystemState.fromJson(jsonMap);
      _stateController.add(newState);
    } catch (e) {
      debugPrint('Error parsing MQTT message: $e');
    }
  }

  void publishCommand(String command, String value) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(value);
    client.publishMessage(
      'water_system/commands/$command',
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }
}

final mqttServiceProvider = Provider((ref) => MqttService());
