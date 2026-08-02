import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ── Domain types ──────────────────────────────────────────────────────────────

enum BridgeStatus { ok, error, webMode }

class BridgeHealth {
  final BridgeStatus status;
  final String mqttStatus;
  final String dbStatus;
  final String? errorMessage;
  final double? uptime;

  const BridgeHealth({
    required this.status,
    this.mqttStatus = 'unknown',
    this.dbStatus = 'unknown',
    this.errorMessage,
    this.uptime,
  });

  /// Convenience: both MQTT and DB must be healthy.
  bool get isFullyOperational =>
      status == BridgeStatus.ok &&
      mqttStatus == 'connected' &&
      dbStatus == 'ready';

  /// Initial state while the first poll hasn't completed yet.
  static const BridgeHealth checking = BridgeHealth(
    status: BridgeStatus.error,
    errorMessage: 'Verificando servicios...',
  );

  static const BridgeHealth bridgeDown = BridgeHealth(
    status: BridgeStatus.error,
    errorMessage:
        "Bridge Offline: Ejecuta 'node index.js' en tu terminal",
  );

  /// Used on Flutter Web where localhost HTTP calls are blocked by the browser.
  static const BridgeHealth webMode = BridgeHealth(
    status: BridgeStatus.webMode,
    errorMessage: 'Modo Web — bridge local no disponible (normal)',
  );
}

// ── StateNotifier ─────────────────────────────────────────────────────────────

class BridgeHealthNotifier extends StateNotifier<BridgeHealth> {
  static const String _healthUrl = 'https://watersmart-backend.onrender.com/api/health';
  static const Duration _pollInterval = Duration(seconds: 10);

  /// Short delay before first poll. Processes are started manually so they
  /// are usually already running when the app opens.
  static const Duration _initialDelay = Duration(seconds: 2);

  Timer? _timer;

  BridgeHealthNotifier() : super(BridgeHealth.checking) {
    _start();
  }

  void _start() {
    // Flutter Web cannot reach localhost:3001 due to browser CORS/security.
    // Skip polling and immediately signal the web-mode bypass state.
    if (kIsWeb) {
      state = BridgeHealth.webMode;
      debugPrint('ℹ️ Bridge health: Modo Web — polling local desactivado.');
      return;
    }

    debugPrint('⏳ Bridge health: esperando ${_initialDelay.inSeconds}s para que Node.js arranque...');

    // First poll after a grace period so node has time to bind its HTTP port.
    Future.delayed(_initialDelay, () {
      if (!mounted) return;
      _poll();
      _timer = Timer.periodic(_pollInterval, (_) => _poll());
    });
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final response = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        state = BridgeHealth(
          status: BridgeStatus.ok,
          mqttStatus: data['mqtt'] as String? ?? 'unknown',
          dbStatus: data['db'] as String? ?? 'unknown',
          uptime: (data['uptime'] as num?)?.toDouble(),
        );
        debugPrint(
            '✅ Bridge health OK — MQTT: ${state.mqttStatus}, DB: ${state.dbStatus}');
      } else {
        state = BridgeHealth.bridgeDown;
        debugPrint('⚠️ Bridge respondió con status ${response.statusCode}');
      }
    } catch (e) {
      state = BridgeHealth.bridgeDown;
      debugPrint('❌ Bridge health check falló: $e');
    }
  }

  /// Force an immediate poll (e.g. after the user hits "reintentar").
  /// No-op on web.
  Future<void> refresh() async {
    if (kIsWeb) return;
    await _poll();
  }

  /// Sincroniza el Modo Prueba con el backend Node.js.
  /// Llama POST http://localhost:3001/api/test-mode { "active": true|false }.
  /// Funciona tanto en desktop como en web — el backend tiene CORS habilitado.
  Future<void> setTestMode(bool active) async {
    // ⚠️ Se eliminó el guard `if (kIsWeb) return` que impedía sincronizar el
    // backend en modo web, dejando las reglas automáticas activas y
    // contrarrestando los comandos del usuario aunque el toggle estuviera ON.
    try {
      final body = active ? '{"active": true}' : '{"active": false}';
      await http
          .post(
            Uri.parse('https://watersmart-backend.onrender.com/api/test-mode'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 4));
      debugPrint('🧪 Backend test-mode → ${active ? "ACTIVADO" : "DESACTIVADO"}');
    } catch (e) {
      debugPrint('⚠️ No se pudo sincronizar test-mode con el backend: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final bridgeHealthProvider =
    StateNotifierProvider<BridgeHealthNotifier, BridgeHealth>(
  (ref) => BridgeHealthNotifier(),
);
