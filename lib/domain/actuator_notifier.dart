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
  final bool fuente1Active; // true only when BOTH bomba=1 AND solenoide=1
  final bool fuente2Active; // stub — local toggle only

  /// Which fuente is awaiting MQTT confirmation (shows spinner in UI).
  final FuenteType? pending;

  /// Tracks partial Fuente 1 echo progress.
  final bool _pumEchoReceived;
  final bool _solEchoReceived;

  const ActuatorState({
    this.fuente1Active      = false,
    this.fuente2Active      = false,
    this.pending,
    bool pumpEchoReceived   = false,
    bool solEchoReceived    = false,
  })  : _pumEchoReceived = pumpEchoReceived,
        _solEchoReceived = solEchoReceived;

  bool get pumpEchoReceived => _pumEchoReceived;
  bool get solEchoReceived  => _solEchoReceived;

  ActuatorState copyWith({
    bool? fuente1Active,
    bool? fuente2Active,
    Object? pending         = _sentinel,
    bool? pumpEchoReceived,
    bool? solEchoReceived,
  }) =>
      ActuatorState(
        fuente1Active      : fuente1Active      ?? this.fuente1Active,
        fuente2Active      : fuente2Active      ?? this.fuente2Active,
        pending            : identical(pending, _sentinel) ? this.pending : pending as FuenteType?,
        pumpEchoReceived   : pumpEchoReceived   ?? _pumEchoReceived,
        solEchoReceived    : solEchoReceived    ?? _solEchoReceived,
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

  /// Called every time the MQTT stream delivers a new hardware state.
  /// Fuente 1 is confirmed active only when BOTH pump AND solenoid are ON.
  void syncFromMqtt({required bool isPump, required bool isSolenoid}) {
    // Not pending Fuente 1 — just mirror the hardware state
    if (state.pending == null || state.pending == FuenteType.fuente2) {
      state = state.copyWith(
        fuente1Active    : isPump && isSolenoid,
        pumpEchoReceived : isPump,
        solEchoReceived  : isSolenoid,
        pending          : null,
      );
      return;
    }

    // Fuente 1 is pending — accumulate echos
    if (state.pending == FuenteType.fuente1) {
      final newPumpEcho = state.pumpEchoReceived || isPump;
      final newSolEcho  = state.solEchoReceived  || isSolenoid;

      if (newPumpEcho && newSolEcho) {
        // Both echos received → CONFIRMED
        debugPrint('✅ Fuente 1 confirmada por MQTT (bomba + solenoide)');
        _timeout?.cancel();
        state = state.copyWith(
          fuente1Active    : true,
          pending          : null,
          pumpEchoReceived : false,
          solEchoReceived  : false,
        );
      } else {
        // Partial — wait for the second echo
        debugPrint('⏳ Fuente 1: eco parcial — bomba=$newPumpEcho, solenoide=$newSolEcho');
        state = state.copyWith(
          pumpEchoReceived : newPumpEcho,
          solEchoReceived  : newSolEcho,
        );
      }
    }
  }

  // ── User command ──────────────────────────────────────────────────────────

  void toggle(FuenteType fuente) {
    if (state.pending != null) return; // block rapid taps while pending

    if (fuente == FuenteType.fuente2) {
      // Stub — toggle locally, no MQTT
      state = state.copyWith(fuente2Active: !state.fuente2Active);
      debugPrint('ℹ️ Fuente 2 (stub): toggled to ${state.fuente2Active}');
      return;
    }

    // ── Fuente 1: dual MQTT command ───────────────────────────────────────
    final desired = !state.fuente1Active;
    final value   = desired ? '1' : '0';

    state = state.copyWith(
      pending          : FuenteType.fuente1,
      pumpEchoReceived : false,
      solEchoReceived  : false,
    );

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      debugPrint('📤 Fuente 1 → bomba=$value, solenoide=$value');
      _repo.sendCommand('bomba',     value);
      _repo.sendCommand('solenoide', value);

      // Safety timeout: clear pending if echos don't arrive
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: _timeoutSec), () {
        if (state.pending == FuenteType.fuente1) {
          final partial = state.pumpEchoReceived || state.solEchoReceived;
          debugPrint('⚠️ Timeout Fuente 1 — eco parcial: $partial. Forzando estado=$desired');
          state = state.copyWith(
            fuente1Active    : desired && partial, // partial success
            pending          : null,
            pumpEchoReceived : false,
            solEchoReceived  : false,
          );
        }
      });
    });
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

  // Keep actuator state in sync with the live MQTT stream
  ref.listen(processedSystemStateProvider, (_, next) {
    notifier.syncFromMqtt(
      isPump     : next.isPumpActive,
      isSolenoid : next.isSolenoidOpen,
    );
  });

  return notifier;
});
