// Conditional import entry point.
// Dart selects the right implementation at compile time:
//   dart.library.html → browser → mqtt_client_factory_web.dart
//   dart.library.io   → native  → mqtt_client_factory_io.dart
export 'mqtt_client_factory_stub.dart'
    if (dart.library.html) 'mqtt_client_factory_web.dart'
    if (dart.library.io) 'mqtt_client_factory_io.dart'
    show createMqttClient, configureTls;
