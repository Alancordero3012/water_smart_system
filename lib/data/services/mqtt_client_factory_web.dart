import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

/// Creates an MQTT client for Flutter Web.
///
/// Uses WebSocket Secure (WSS) on port 8884 — HiveMQ Cloud WebSocket endpoint.
/// The port is embedded directly in the URL to avoid any ambiguity in how
/// MqttBrowserClient handles the withPort constructor.
MqttClient createMqttClient(String broker, String clientId, int port) {
  // Embed port directly in URL: wss://broker:8884
  // HiveMQ Cloud does NOT require a /mqtt path for WebSocket connections.
  final wsUrl = 'wss://$broker:$port';
  final client = MqttBrowserClient(wsUrl, clientId);

  // Required: tells HiveMQ Cloud we are speaking MQTT over WebSocket.
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

  return client;
}

// TLS is implicit in WSS — no extra configuration needed.
void configureTls(MqttClient client) {}
