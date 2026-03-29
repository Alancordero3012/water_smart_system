import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Creates an MQTT client for native platforms (Windows / macOS / Linux / mobile).
/// Uses raw TLS over TCP (port 8883).
MqttClient createMqttClient(String broker, String clientId, int port) {
  final client = MqttServerClient.withPort(broker, clientId, port);
  client.secure = true;
  return client;
}

// No extra TLS config needed — MqttServerClient handles it natively.
void configureTls(MqttClient client) {}
