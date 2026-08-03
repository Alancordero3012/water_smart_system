import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/water_data_repository.dart';
import '../data/services/preferences_service.dart';
import 'providers.dart';

// ── Estado del botón de bomba ─────────────────────────────────────────────────

/// Estado del gran botón industrial de la Bomba.
///
/// [confirmedOn]  → estado confirmado por eco MQTT del hardware (mueve el LED).
/// [isPending]    → se publicó el comando, esperando eco (muestra spinner).
/// [desiredOn]    → valor que queremos alcanzar (para timeout de seguridad).
/// [_commandSentAt] → timestamp del último comando enviado.
class BombaButtonState {
  final bool confirmedOn;
  final bool isPending;
  final bool? desiredOn;
  final DateTime? _commandSentAt;

  const BombaButtonState({
    this.confirmedOn = false,
    this.isPending   = false,
    this.desiredOn,
    DateTime? commandSentAt,
  }) : _commandSentAt = commandSentAt;

  BombaButtonState copyWith({
    bool? confirmedOn,
    bool? isPending,
    Object? desiredOn      = _sentinel,
    Object? commandSentAt  = _sentinel,
  }) =>
      BombaButtonState(
        confirmedOn   : confirmedOn    ?? this.confirmedOn,
        isPending     : isPending      ?? this.isPending,
        desiredOn     : identical(desiredOn, _sentinel)
            ? this.desiredOn
            : desiredOn as bool?,
        commandSentAt : identical(commandSentAt, _sentinel)
            ? _commandSentAt
            : commandSentAt as DateTime?,
      );

  static const _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class BombaNotifier extends StateNotifier<BombaButtonState> {
  final WaterDataRepository _repo;
  final PreferencesService  _prefs;
  Timer? _timeout;

  /// Segundos máximos esperando el eco MQTT antes de cancelar el pending.
  static const _timeoutSec = 8;

  BombaNotifier(this._repo, this._prefs) : super(const BombaButtonState());

  // ── Sincronización desde el stream MQTT ──────────────────────────────────

  /// Llamado por el listener del stream cuando llega un eco del broker.
  /// SÓLO actualiza [confirmedOn] después de la ventana mínima de round-trip.
  void syncFromMqtt(bool isPumpActive) {
    if (!state.isPending) {
      state = state.copyWith(confirmedOn: isPumpActive, isPending: false);
      return;
    }

    if (isPumpActive == state.desiredOn) {
      debugPrint('✅ Bomba: eco MQTT real recibido — confirmedOn=$isPumpActive');
      _timeout?.cancel();
      state = state.copyWith(
        confirmedOn   : isPumpActive,
        isPending     : false,
        desiredOn     : null,
        commandSentAt : null,
      );
    }
  }

  // ── Acción del usuario ────────────────────────────────────────────────────

  /// Togglea la bomba: publica "1"/"0" en `agua_iot/actuadores/bomba`.
  /// Al ENCENDER: activa automáticamente la fuente prioritaria configurada en Settings.
  /// Al APAGAR: apaga todas las fuentes secundarias (cascade-off).
  void toggle() {
    if (state.isPending) return; // bloquear doble-tap mientras hay pendiente

    final desired = !state.confirmedOn;
    final payload = desired ? '1' : '0';

    debugPrint('📤 BombaNOTIFIER → agua_iot/actuadores/bomba = $payload');

    if (!desired) {
      // ── CASCADE OFF ─────────────────────────────────────────────────────────
      // Al apagar la Bomba Principal, apagar también todas las fuentes.
      debugPrint('🔒 Cascade OFF → apagando bomba_calle, solenoide_calle, bomba_lluvia, solenoide_lluvia');
      _repo.sendCommand('bomba_calle',     '0');
      _repo.sendCommand('solenoide_calle', '0');
      _repo.sendCommand('bomba_lluvia',    '0');
      _repo.sendCommand('solenoide_lluvia','0');
    } else {
      // ── CASCADE ON ──────────────────────────────────────────────────────────
      // Al encender la Bomba Principal, activar automáticamente la fuente
      // configurada como prioritaria en Configuración → Fuente prioritaria.
      final source = _prefs.prioritySource; // 'rain' | 'street'
      if (source == 'rain') {
        debugPrint('⚡ Cascade ON → activando fuente LLUVIA (prioritaria)');
        _repo.sendCommand('bomba_lluvia',    '1');
        _repo.sendCommand('solenoide_lluvia','1');
      } else {
        debugPrint('⚡ Cascade ON → activando fuente CALLE (prioritaria)');
        _repo.sendCommand('bomba_calle',     '1');
        _repo.sendCommand('solenoide_calle', '1');
      }
    }

    state = state.copyWith(
      isPending     : true,
      desiredOn     : desired,
      commandSentAt : DateTime.now(),
    );

    // Publicación al tópico de la bomba principal
    _repo.sendCommand('bomba', payload);

    // Timeout de seguridad
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: _timeoutSec), () {
      if (state.isPending) {
        debugPrint('⚠️ Bomba timeout: sin eco MQTT real. Revirtiendo pending.');
        state = state.copyWith(
          isPending     : false,
          desiredOn     : null,
          commandSentAt : null,
        );
      }
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final bombaProvider =
    StateNotifierProvider<BombaNotifier, BombaButtonState>((ref) {
  final repo     = ref.watch(waterDataRepositoryProvider);
  final prefs    = ref.watch(preferencesServiceProvider);
  final notifier = BombaNotifier(repo, prefs);

  // Escucha el stream MQTT para recibir confirmaciones por eco
  ref.listen(processedSystemStateProvider, (_, next) {
    notifier.syncFromMqtt(next.isPumpActive);
  });

  return notifier;
});
