import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/water_data_repository.dart';
import 'providers.dart';

// ── Fuente identifiers ────────────────────────────────────────────────────────

enum FuenteType { fuente1, fuente2 }

// ── Actuator state ────────────────────────────────────────────────────────────

/// Tracks both the confirmed hardware state and any pending operation.
///
/// Fuente 1 = Bomba + Solenoide (dual MQTT command).
///   Confirmed active only when BOTH pump AND solenoid echos arrive.
///
/// Fuente 2 = stub (no physical actuator in current circuit).
class ActuatorState {
  /// Hardware-confirmed states (from MQTT echo).
  final bool fuente1Active; // true solo cuando AMBOS bomba_calle=1 Y solenoide_calle=1
  final bool fuente2Active; // true solo cuando AMBOS bomba_lluvia=1 Y solenoide_lluvia=1

  /// Which fuente is awaiting MQTT confirmation (shows spinner in UI).
  final FuenteType? pending;

  /// Fuente 1 eco parcial
  final bool _pumEchoReceived;
  final bool _solEchoReceived;

  /// Fuente 2 eco parcial
  final bool _pump2EchoReceived;
  final bool _sol2EchoReceived;

  const ActuatorState({
    this.fuente1Active       = false,
    this.fuente2Active       = false,
    this.pending,
    bool pumpEchoReceived    = false,
    bool solEchoReceived     = false,
    bool pump2EchoReceived   = false,
    bool sol2EchoReceived    = false,
  })  : _pumEchoReceived   = pumpEchoReceived,
        _solEchoReceived   = solEchoReceived,
        _pump2EchoReceived = pump2EchoReceived,
        _sol2EchoReceived  = sol2EchoReceived;

  bool get pumpEchoReceived  => _pumEchoReceived;
  bool get solEchoReceived   => _solEchoReceived;
  bool get pump2EchoReceived => _pump2EchoReceived;
  bool get sol2EchoReceived  => _sol2EchoReceived;

  ActuatorState copyWith({
    bool? fuente1Active,
    bool? fuente2Active,
    Object? pending          = _sentinel,
    bool? pumpEchoReceived,
    bool? solEchoReceived,
    bool? pump2EchoReceived,
    bool? sol2EchoReceived,
  }) =>
      ActuatorState(
        fuente1Active      : fuente1Active      ?? this.fuente1Active,
        fuente2Active      : fuente2Active      ?? this.fuente2Active,
        pending            : identical(pending, _sentinel) ? this.pending : pending as FuenteType?,
        pumpEchoReceived   : pumpEchoReceived   ?? _pumEchoReceived,
        solEchoReceived    : solEchoReceived    ?? _solEchoReceived,
        pump2EchoReceived  : pump2EchoReceived  ?? _pump2EchoReceived,
        sol2EchoReceived   : sol2EchoReceived   ?? _sol2EchoReceived,
      );

  static const _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ActuatorNotifier extends StateNotifier<ActuatorState> {
  final WaterDataRepository _repo;
  Timer? _debounce;
  Timer? _timeout;

  static const _debounceMs = 500;
  static const _timeoutSec = 6; // safety timeout for MQTT echo

  ActuatorNotifier(this._repo) : super(const ActuatorState());

  // ── External sync (called by stream listener) ─────────────────────────────

  /// Recibe el estado actualizado de TODOS los actuadores desde el stream MQTT.
  /// Fuente Calle confirma con isBombaCalle + isSolCalle (desacoplado de BombaButton).
  /// Fuente Lluvia confirma con isBombaLluvia + isSoleLluvia.
  void syncFromMqtt({
    required bool isBombaCalle,
    required bool isSolCalle,
    required bool isBombaLluvia,
    required bool isSoleLluvia,
  }) {
    // ── Fuente Calle ──────────────────────────────────────────────────────────
    if (state.pending == null || state.pending == FuenteType.fuente2) {
      state = state.copyWith(
        fuente1Active    : isBombaCalle && isSolCalle,
        pumpEchoReceived : isBombaCalle,
        solEchoReceived  : isSolCalle,
      );
    } else if (state.pending == FuenteType.fuente1) {
      final newPumpEcho = state.pumpEchoReceived || isBombaCalle;
      final newSolEcho  = state.solEchoReceived  || isSolCalle;
      if (newPumpEcho && newSolEcho) {
        debugPrint('✅ Fuente Calle confirmada — bomba_calle + solenoide_calle');
        _timeout?.cancel();
        state = state.copyWith(
          fuente1Active    : true,
          pending          : null,
          pumpEchoReceived : false,
          solEchoReceived  : false,
        );
      } else {
        state = state.copyWith(
          pumpEchoReceived: newPumpEcho,
          solEchoReceived : newSolEcho,
        );
      }
    }

    // ── Fuente 2 ────────────────────────────────────────────────────────────
    if (state.pending == null || state.pending == FuenteType.fuente1) {
      state = state.copyWith(
        fuente2Active      : isBombaLluvia && isSoleLluvia,
        pump2EchoReceived  : isBombaLluvia,
        sol2EchoReceived   : isSoleLluvia,
      );
    } else if (state.pending == FuenteType.fuente2) {
      final newPump2Echo = state.pump2EchoReceived || isBombaLluvia;
      final newSol2Echo  = state.sol2EchoReceived  || isSoleLluvia;
      if (newPump2Echo && newSol2Echo) {
        debugPrint('✅ Fuente Lluvia confirmada — bomba_lluvia + solenoide_lluvia');
        _timeout?.cancel();
        state = state.copyWith(
          fuente2Active      : true,
          pending            : null,
          pump2EchoReceived  : false,
          sol2EchoReceived   : false,
        );
      } else {
        state = state.copyWith(
          pump2EchoReceived: newPump2Echo,
          sol2EchoReceived : newSol2Echo,
        );
      }
    }
  }

  // ── User command ──────────────────────────────────────────────────────────

  //  ⚠️ REGLA DE EXCLUSIÓN MUTUA:
  //  Fuente 1 (CALLE) y Fuente 2 (LLUVIA) NO pueden estar activas al mismo tiempo.
  //  Si se intenta encender una mientras la otra está activa, primero se apaga
  //  la activa y luego se enciende la nueva (con el debounce normal como buffer).

  void toggle(FuenteType fuente) {
    if (state.pending != null) return;

    if (fuente == FuenteType.fuente1) {
      final desired = !state.fuente1Active;
      final value   = desired ? '1' : '0';

      // ── INTERLOCK ────────────────────────────────────────────────────────
      // Si queremos ENCENDER Fuente 1 y Fuente 2 está activa → apagar Fuente 2
      if (desired && state.fuente2Active) {
        debugPrint('🔒 Interlock: apagando Fuente 2 (LLUVIA) → Fuente 1 (CALLE) tomará el control');
        _repo.sendCommand('bomba_lluvia',     '0');
        _repo.sendCommand('solenoide_lluvia', '0');
        // El eco llegará y actualizará fuente2Active=false vía syncFromMqtt
      }

      state = state.copyWith(
        pending          : FuenteType.fuente1,
        pumpEchoReceived : false,
        solEchoReceived  : false,
      );
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
        debugPrint('📤 Fuente 1 (CALLE) → bomba_calle=$value, solenoide_calle=$value');
        _repo.sendCommand('bomba_calle',     value);
        _repo.sendCommand('solenoide_calle', value);
        _timeout?.cancel();
        _timeout = Timer(const Duration(seconds: _timeoutSec), () {
          if (state.pending == FuenteType.fuente1) {
            debugPrint('⚠️ Timeout Fuente 1 — forzando estado=$desired');
            state = state.copyWith(
              fuente1Active    : desired && (state.pumpEchoReceived || state.solEchoReceived),
              pending          : null,
              pumpEchoReceived : false,
              solEchoReceived  : false,
            );
          }
        });
      });
    } else {
      // ── Fuente 2: LLUVIA ─────────────────────────────────────────────────
      final desired = !state.fuente2Active;
      final value   = desired ? '1' : '0';

      // ── INTERLOCK ────────────────────────────────────────────────────────
      // Si queremos ENCENDER Fuente 2 y Fuente 1 está activa → apagar Fuente 1
      if (desired && state.fuente1Active) {
        debugPrint('🔒 Interlock: apagando Fuente 1 (CALLE) → Fuente 2 (LLUVIA) tomará el control');
        _repo.sendCommand('bomba_calle',     '0');
        _repo.sendCommand('solenoide_calle', '0');
        // El eco llegará y actualizará fuente1Active=false vía syncFromMqtt
      }

      state = state.copyWith(
        pending           : FuenteType.fuente2,
        pump2EchoReceived : false,
        sol2EchoReceived  : false,
      );
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
        debugPrint('📤 Fuente 2 (LLUVIA) → bomba_lluvia=$value, solenoide_lluvia=$value');
        _repo.sendCommand('bomba_lluvia',     value);
        _repo.sendCommand('solenoide_lluvia', value);
        _timeout?.cancel();
        _timeout = Timer(const Duration(seconds: _timeoutSec), () {
          if (state.pending == FuenteType.fuente2) {
            debugPrint('⚠️ Timeout Fuente 2 — forzando estado=$desired');
            state = state.copyWith(
              fuente2Active      : desired && (state.pump2EchoReceived || state.sol2EchoReceived),
              pending            : null,
              pump2EchoReceived  : false,
              sol2EchoReceived   : false,
            );
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _timeout?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final actuatorProvider =
    StateNotifierProvider<ActuatorNotifier, ActuatorState>((ref) {
  final repo     = ref.watch(waterDataRepositoryProvider);
  final notifier = ActuatorNotifier(repo);

  ref.listen(processedSystemStateProvider, (_, next) {
    notifier.syncFromMqtt(
      isBombaCalle  : next.isBombaCalleActive,
      isSolCalle    : next.isSolenoideCalleOpen,
      isBombaLluvia : next.isBombaLluviaActive,
      isSoleLluvia  : next.isSoleLluviaOpen,
    );
  });

  return notifier;
});
