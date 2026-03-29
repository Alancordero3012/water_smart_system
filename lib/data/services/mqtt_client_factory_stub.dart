import 'package:mqtt_client/mqtt_client.dart';

// Default stub — overridden by conditional imports in mqtt_client_factory.dart
MqttClient createMqttClient(String broker, String clientId, int port) {
  throw UnimplementedError(
      'createMqttClient: plataforma no reconocida.');
}

void configureTls(MqttClient client) {}
