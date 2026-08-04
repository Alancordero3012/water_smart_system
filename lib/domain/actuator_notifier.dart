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

  void syncFromMqtt({
    required bool isBombaCalle,
    required bool isSolCalle,
    required bool isBombaLluvia,
    required bool isSoleLluvia,
  }) {
    debugPrint('[ACT-SYNC] 📥 isBombaCalle=$isBombaCalle isSolCalle=$isSolCalle '
        'isBombaLluvia=$isBombaLluvia isSoleLluvia=$isSoleLluvia '
        '| pending=${state.pending} f1=${state.fuente1Active} f2=${state.fuente2Active}');

    // ── Fuente Calle ──────────────────────────────────────────────────────────
    if (state.pending == null || state.pending == FuenteType.fuente2) {
      final newF1 = isBombaCalle && isSolCalle;
      if (newF1 != state.fuente1Active) {
        debugPrint('[ACT-SYNC] ⚠️ Fuente1 echo directo (pending=${state.pending}): f1Active → $newF1');
      }
      state = state.copyWith(
        fuente1Active    : newF1,
        pumpEchoReceived : isBombaCalle,
        solEchoReceived  : isSolCalle,
      );
    } else if (state.pending == FuenteType.fuente1) {
      final newPumpEcho = state.pumpEchoReceived || isBombaCalle;
      final newSolEcho  = state.solEchoReceived  || isSolCalle;
      debugPrint('[ACT-SYNC] 🏭 Fuente1 pending — pumpEcho=$newPumpEcho solEcho=$newSolEcho');
      if (newPumpEcho && newSolEcho) {
        debugPrint('[ACT-SYNC] ✅ Fuente Calle CONFIRMADA ON — f1Active=true, pending=null');
        _timeout?.cancel();
        state = state.copyWith(
          fuente1Active    : true,
          pending          : null,
          pumpEchoReceived : false,
          solEchoReceived  : false,
        );
      } else if (!isBombaCalle && !isSolCalle && state.fuente1Active) {
        debugPrint('[ACT-SYNC] ✅ Fuente Calle CONFIRMADA OFF — f1Active=false, pending=null');
        _timeout?.cancel();
        state = state.copyWith(
          fuente1Active    : false,
          pending          : null,
          pumpEchoReceived : false,
          solEchoReceived  : false,
        );
      } else {
        debugPrint('[ACT-SYNC] ⏳ Fuente1 acumulando ecos: pump=$newPumpEcho sol=$newSolEcho');
        state = state.copyWith(
          pumpEchoReceived: newPumpEcho,
          solEchoReceived : newSolEcho,
        );
      }
    }

    // ── Fuente 2 ────────────────────────────────────────────────────────────
    if (state.pending == null || state.pending == FuenteType.fuente1) {
      final newF2 = isBombaLluvia && isSoleLluvia;
      if (newF2 != state.fuente2Active) {
        debugPrint('[ACT-SYNC] ⚠️ Fuente2 echo directo (pending=${state.pending}): f2Active → $newF2');
      }
      state = state.copyWith(
        fuente2Active      : newF2,
        pump2EchoReceived  : isBombaLluvia,
        sol2EchoReceived   : isSoleLluvia,
      );
    } else if (state.pending == FuenteType.fuente2) {
      final newPump2Echo = state.pump2EchoReceived || isBombaLluvia;
      final newSol2Echo  = state.sol2EchoReceived  || isSoleLluvia;
      debugPrint('[ACT-SYNC] 🌧️ Fuente2 pending — pumpEcho=$newPump2Echo solEcho=$newSol2Echo');
      if (newPump2Echo && newSol2Echo) {
        debugPrint('[ACT-SYNC] ✅ Fuente Lluvia CONFIRMADA ON — f2Active=true, pending=null');
        _timeout?.cancel();
        state = state.copyWith(
          fuente2Active      : true,
          pending            : null,
          pump2EchoReceived  : false,
          sol2EchoReceived   : false,
        );
      } else if (!isBombaLluvia && !isSoleLluvia && state.fuente2Active) {
        debugPrint('[ACT-SYNC] ✅ Fuente Lluvia CONFIRMADA OFF — f2Active=false, pending=null');
        _timeout?.cancel();
        state = state.copyWith(
          fuente2Active      : false,
          pending            : null,
          pump2EchoReceived  : false,
          sol2EchoReceived   : false,
        );
      } else {
        debugPrint('[ACT-SYNC] ⏳ Fuente2 acumulando ecos: pump=$newPump2Echo sol=$newSol2Echo');
        state = state.copyWith(
          pump2EchoReceived: newPump2Echo,
          sol2EchoReceived : newSol2Echo,
        );
      }
    }
  }

  // ── User command ──────────────────────────────────────────────────────────

  void toggle(FuenteType fuente, {bool bypassInterlock = false}) {
    debugPrint('[ACT-TOGGLE] 🔘 toggle(${fuente.name}) | pending=${state.pending} '
        'f1=${state.fuente1Active} f2=${state.fuente2Active}');
    if (state.pending != null) {
      debugPrint('[ACT-TOGGLE] ⏳ BLOQUEADO — ya hay operación pendiente: ${state.pending}');
      return;
    }

    if (fuente == FuenteType.fuente1) {
      final desired = !state.fuente1Active;
      final value   = desired ? '1' : '0';
      debugPrint('[ACT-TOGGLE] 🏭 Fuente1(CALLE): desired=$desired');

      if (!bypassInterlock && desired && state.fuente2Active) {
        debugPrint('[ACT-TOGGLE] 🔒 Interlock: apagando Fuente2(LLUVIA) primero');
        _repo.sendCommand('bomba_lluvia',     '0');
        _repo.sendCommand('solenoide_lluvia', '0');
      }

      state = state.copyWith(
        pending          : FuenteType.fuente1,
        pumpEchoReceived : false,
        solEchoReceived  : false,
      );
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
        debugPrint('[ACT-TOGGLE] 📤 Debounce fired → bomba_calle=$value solenoide_calle=$value');
        _repo.sendCommand('bomba_calle',     value);
        _repo.sendCommand('solenoide_calle', value);
        _timeout?.cancel();
        _timeout = Timer(const Duration(seconds: _timeoutSec), () {
          if (state.pending == FuenteType.fuente1) {
            debugPrint('[ACT-TIMEOUT] ⚠️ TIMEOUT Fuente1 (${_timeoutSec}s sin eco). '
                'pump=${state.pumpEchoReceived} sol=${state.solEchoReceived}. '
                'Forzando fuente1Active=${desired && (state.pumpEchoReceived || state.solEchoReceived)}');
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
      debugPrint('[ACT-TOGGLE] 🌧️ Fuente2(LLUVIA): desired=$desired');

      if (!bypassInterlock && desired && state.fuente1Active) {
        debugPrint('[ACT-TOGGLE] 🔒 Interlock: apagando Fuente1(CALLE) primero');
        _repo.sendCommand('bomba_calle',     '0');
        _repo.sendCommand('solenoide_calle', '0');
      }

      state = state.copyWith(
        pending           : FuenteType.fuente2,
        pump2EchoReceived : false,
        sol2EchoReceived  : false,
      );
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
        debugPrint('[ACT-TOGGLE] 📤 Debounce fired → bomba_lluvia=$value solenoide_lluvia=$value');
        _repo.sendCommand('bomba_lluvia',     value);
        _repo.sendCommand('solenoide_lluvia', value);
        _timeout?.cancel();
        _timeout = Timer(const Duration(seconds: _timeoutSec), () {
          if (state.pending == FuenteType.fuente2) {
            debugPrint('[ACT-TIMEOUT] ⚠️ TIMEOUT Fuente2 (${_timeoutSec}s sin eco). '
                'pump=${state.pump2EchoReceived} sol=${state.sol2EchoReceived}. '
                'Forzando fuente2Active=${desired && (state.pump2EchoReceived || state.sol2EchoReceived)}');
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
