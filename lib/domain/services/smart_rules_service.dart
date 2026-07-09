import 'package:flutter/foundation.dart';
import '../../data/services/preferences_service.dart';
import '../repositories/water_data_repository.dart';
import '../models/water_system_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartRulesService — Motor de Reglas Inteligentes
//
// PRINCIPIO CENTRAL:
//   Si hay falla en la fuente activa → cambiar a la fuente de respaldo.
//   Solo apagar todo si AMBAS fuentes están no disponibles.
//
// Las reglas de diagnóstico (sensor inconsistente, fuga) solo alertan.
// Las reglas de acción (rotura, presión, flujo) hacen failover o detienen.
//
// Este servicio es STATEFUL: rastrea tiempos para reglas basadas en duración.
// ─────────────────────────────────────────────────────────────────────────────

class SmartRulesService {
  final PreferencesService _preferences;
  final WaterDataRepository _repo;

  SmartRulesService(this._preferences, this._repo);

  // ── Umbrales configurables ───────────────────────────────────────────────
  static const double _minPressure     = 10.0;  // PSI — bajo este valor = falla
  static const double _maxPressure     = 45.0;  // PSI — sobre este = bloqueo
  static const double _maxTurbidity    = 50.0;  // NTU
  static const double _minFlowAnomaly  = 0.5;   // L/min — fuga si sistema apagado
  static const double _minTankLevel    = 15.0;  // % — bajo este no usamos esa fuente
  static const int    _faultWindowSec  = 30;    // segundos antes de trigger de rotura

  // ── Estado interno (tracking de tiempo) ─────────────────────────────────
  DateTime? _flowZeroSince;       // cuándo el flujo cayó a 0 con bomba activa
  DateTime? _presionBajaSince;    // cuándo la presión bajó de _minPressure
  DateTime? _lastFailover;        // último failover para cooldown
  String    _autoDescPendiente = ''; // descripción del autoAction para próximo estado

  static const _failoverCooldown = Duration(seconds: 90);

  // ── Mapa de mensajes legibles por regla ─────────────────────────────────
  static const Map<String, String> _faultMessages = {
    'rotura_tuberia_calle'       : '⛔ Rotura/bloqueo en línea CALLE — cambiando a LLUVIA',
    'rotura_tuberia_lluvia'      : '⛔ Rotura/bloqueo en línea LLUVIA — cambiando a CALLE',
    'fuga_detectada'             : '⚠️ Fuga detectada — flujo activo con sistema apagado',
    'presion_critica_alta_calle' : '⚠️ Presión muy alta en CALLE — bomba detenida',
    'presion_critica_alta_lluvia': '⚠️ Presión muy alta en LLUVIA — bomba detenida',
    'presion_baja_calle'         : '⚠️ Presión baja en CALLE — cambiando a LLUVIA',
    'presion_baja_lluvia'        : '⚠️ Presión baja en LLUVIA — cambiando a CALLE',
    'sensor_inconsistente_calle' : '🔧 Sensor inconsistente en Tanque CALLE — verificar hardware',
    'sensor_inconsistente_lluvia': '🔧 Sensor inconsistente en Tanque LLUVIA — verificar hardware',
    'agua_turbia_activa'         : '⛔ Agua turbia — distribución cerrada automáticamente',
    'sin_fuente_disponible'      : '🚨 CRÍTICO: Ambas fuentes no disponibles — sistema detenido',
    'failover_automatico'        : 'ℹ️ Failover automático ejecutado por el sistema',
    'fuente_prioritaria_restaurada': 'ℹ️ Fuente prioritaria restaurada — volviendo al origen preferido',
  };

  // ── API pública ──────────────────────────────────────────────────────────

  /// Evalúa todas las reglas sobre el estado actual y devuelve el estado
  /// resultante (posiblemente modificado con detectedFault, activeSource, etc.)
  WaterSystemState evaluateRules(WaterSystemState s) {
    // Limpiar log pendiente de ciclo anterior
    final pendingLog = _autoDescPendiente;
    _autoDescPendiente = '';

    WaterSystemState next = s.copyWith(
      autoActionLog: pendingLog,
      detectedFault: '',        // reset — se puede re-setear abajo
      failoverActive: s.failoverActive, // mantener hasta que se resuelva
    );

    // ── Determinar fuente activa real (según echos MQTT) ─────────────────
    next = _actualizarFuenteActiva(next);

    // ── Regla 6: Sensor reed switch inconsistente ─────────────────────────
    next = _checkSensorInconsistente(next);

    // ── Regla 2: Fuga de agua (flujo sin sistema activo) ─────────────────
    next = _checkFugaAgua(next);

    // ── Regla 7: Agua turbia con sistema activo ───────────────────────────
    next = _checkAguaTurbia(next);

    // ── Regla 4: Presión anómala alta ─────────────────────────────────────
    next = _checkPresionAlta(next);

    // ── Regla 1 + 3: Rotura / Presión baja → Failover ────────────────────
    next = _checkFallaFuente(next);

    // ── Regla 5: Restaurar fuente prioritaria ─────────────────────────────
    next = _checkRestaurarFuente(next);

    return next;
  }

  // ── Reglas privadas ──────────────────────────────────────────────────────

  // Actualiza activeSource basándose en cuáles actuadores están REALMENTE activos
  WaterSystemState _actualizarFuenteActiva(WaterSystemState s) {
    if (s.isBombaCalleActive && s.isSolenoideCalleOpen) {
      return s.copyWith(activeSource: 'calle');
    }
    if (s.isBombaLluviaActive && s.isSoleLluviaOpen) {
      return s.copyWith(activeSource: 'lluvia');
    }
    // Si ninguna fuente está activa, mantener la última
    return s;
  }

  // Regla 6 — Sensor inconsistente (S100=agua pero S0=seco = imposible físicamente)
  WaterSystemState _checkSensorInconsistente(WaterSystemState s) {
    // Tanque Calle: si sensor de lleno dice SÍ pero sensor de vacío dice SÍ = imposible
    if (s.calleS100 && s.calleS0) {
      return s.copyWith(
        detectedFault: 'sensor_inconsistente_calle',
      );
    }
    // Tanque Lluvia
    if (s.lluviaS100 && s.lluviaS0) {
      return s.copyWith(
        detectedFault: 'sensor_inconsistente_lluvia',
      );
    }
    return s;
  }

  // Regla 2 — Fuga: flujo > umbral con sistema apagado
  WaterSystemState _checkFugaAgua(WaterSystemState s) {
    final sistemaCerrado = !s.isBombaCalleActive && !s.isBombaLluviaActive &&
                           !s.isSolenoideCalleOpen && !s.isSoleLluviaOpen;
    if (sistemaCerrado && s.flowRate > _minFlowAnomaly) {
      return s.copyWith(detectedFault: 'fuga_detectada');
    }
    return s;
  }

  // Regla 7 — Agua turbia con distribución activa → cerrar solenoides
  WaterSystemState _checkAguaTurbia(WaterSystemState s) {
    if (s.turbidity > _maxTurbidity) {
      final distribuyendo = s.isSolenoideCalleOpen || s.isSoleLluviaOpen;
      if (distribuyendo) {
        // Cerrar ambos solenoides (mantener bombas para proteger el motor)
        _enviarComando('solenoide_calle',   '0');
        _enviarComando('solenoide_lluvia',  '0');
        _autoDescPendiente = _faultMessages['agua_turbia_activa']!;
        debugPrint('[SmartRules] ⛔ Agua turbia — solenoides cerrados automáticamente');
        return s.copyWith(detectedFault: 'agua_turbia_activa');
      }
    }
    return s;
  }

  // Regla 4 — Presión anómala ALTA → apagar bomba de la fuente activa
  WaterSystemState _checkPresionAlta(WaterSystemState s) {
    if (s.streetPressure > _maxPressure) {
      final fuenteActiva = s.activeSource;
      final faultKey = 'presion_critica_alta_$fuenteActiva';
      _enviarComando('bomba_$fuenteActiva', '0');
      _autoDescPendiente = _faultMessages[faultKey] ?? '⚠️ Presión crítica alta';
      debugPrint('[SmartRules] ⚠️ Presión alta — bomba $fuenteActiva detenida');
      return s.copyWith(detectedFault: faultKey);
    }
    return s;
  }

  // Regla 1 + 3 — Rotura de tubería O presión baja → Failover
  WaterSystemState _checkFallaFuente(WaterSystemState s) {
    final sistemaActivo = s.isBombaCalleActive || s.isBombaLluviaActive;
    if (!sistemaActivo) {
      // Sistema no está activo, nada que vigilar
      _flowZeroSince    = null;
      _presionBajaSince = null;
      return s;
    }

    final fuenteActiva = s.activeSource;
    final now          = DateTime.now();
    bool  faltaDetectada = false;
    String faultKey      = '';

    // ── Regla 1: Flujo cero con sistema activo = posible rotura ──────────
    final sistemaSolenoidAbierto = s.isSolenoideCalleOpen || s.isSoleLluviaOpen;
    if (sistemaSolenoidAbierto && s.flowRate < 0.1) {
      _flowZeroSince ??= now;
      final elapsed = now.difference(_flowZeroSince!).inSeconds;
      if (elapsed >= _faultWindowSec) {
        faltaDetectada = true;
        faultKey       = 'rotura_tuberia_$fuenteActiva';
        debugPrint('[SmartRules] ⛔ Flujo cero por ${elapsed}s — posible rotura en $fuenteActiva');
      }
    } else {
      _flowZeroSince = null; // reset si flujo volvió
    }

    // ── Regla 3: Presión baja persistente ────────────────────────────────
    if (!faltaDetectada && s.streetPressure < _minPressure && s.streetPressure > 0) {
      _presionBajaSince ??= now;
      final elapsed = now.difference(_presionBajaSince!).inSeconds;
      if (elapsed >= 20) { // 20s para presión baja
        faltaDetectada = true;
        faultKey       = 'presion_baja_$fuenteActiva';
        debugPrint('[SmartRules] ⚠️ Presión baja por ${elapsed}s — failover desde $fuenteActiva');
      }
    } else {
      _presionBajaSince = null;
    }

    if (!faltaDetectada) return s;

    // ── Ejecutar failover ─────────────────────────────────────────────────
    return _ejecutarFailover(s, fuenteActiva, faultKey);
  }

  // Regla 5 — Restaurar fuente prioritaria si el nivel volvió a subir
  WaterSystemState _checkRestaurarFuente(WaterSystemState s) {
    if (!s.failoverActive) return s;

    final prioridad    = _preferences.prioritySource; // 'rain' | 'street'
    final fuentePref   = prioridad == 'rain' ? 'lluvia' : 'calle';
    final nivelPref    = fuentePref == 'lluvia' ? s.rainTankLevel : s.streetTankLevel;
    final fuenteActiva = s.activeSource;

    // Si ya estamos en la fuente preferida, salir de failover
    if (fuenteActiva == fuentePref) {
      return s.copyWith(failoverActive: false);
    }

    // Si el nivel de la preferida volvió a > 20% y pasó el cooldown
    final cooldownOk = _lastFailover == null ||
        DateTime.now().difference(_lastFailover!).inSeconds > 120;

    if (nivelPref > 20.0 && cooldownOk) {
      debugPrint('[SmartRules] ℹ️ Fuente prioritaria ($fuentePref) restaurada — volviendo');
      return _ejecutarCambioFuente(s, fuentePref, 'fuente_prioritaria_restaurada',
          limpiarFailover: true);
    }

    return s;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  WaterSystemState _ejecutarFailover(
      WaterSystemState s, String fuenteActual, String faultKey) {

    // Cooldown entre failovers para evitar bucles
    if (_lastFailover != null &&
        DateTime.now().difference(_lastFailover!).compareTo(_failoverCooldown) < 0) {
      debugPrint('[SmartRules] ⏸ Failover bloqueado por cooldown');
      return s.copyWith(detectedFault: faultKey);
    }

    final fuenteRespaldo = fuenteActual == 'calle' ? 'lluvia' : 'calle';
    final nivelRespaldo  = fuenteRespaldo == 'lluvia'
        ? s.rainTankLevel
        : s.streetTankLevel;

    if (nivelRespaldo <= _minTankLevel) {
      // ─ Sin fuente de respaldo disponible ─
      debugPrint('[SmartRules] 🚨 Sin fuente de respaldo — deteniendo todo');
      _enviarComando('bomba_calle',      '0');
      _enviarComando('solenoide_calle',  '0');
      _enviarComando('bomba_lluvia',     '0');
      _enviarComando('solenoide_lluvia', '0');
      _autoDescPendiente = _faultMessages['sin_fuente_disponible']!;
      return s.copyWith(
        detectedFault : 'sin_fuente_disponible',
        failoverActive: false,
      );
    }

    // ─ Hay respaldo — hacer failover ─
    return _ejecutarCambioFuente(s, fuenteRespaldo, faultKey, limpiarFailover: false);
  }

  WaterSystemState _ejecutarCambioFuente(
      WaterSystemState s, String nuevaFuente, String faultKey,
      {required bool limpiarFailover}) {

    final fuenteAnterior = s.activeSource;

    // Apagar fuente anterior
    _enviarComando('bomba_$fuenteAnterior',      '0');
    _enviarComando('solenoide_$fuenteAnterior',  '0');

    // Encender nueva fuente
    _enviarComando('bomba_$nuevaFuente',     '1');
    _enviarComando('solenoide_$nuevaFuente', '1');

    _lastFailover       = DateTime.now();
    _flowZeroSince      = null;
    _presionBajaSince   = null;

    final msg = _faultMessages[faultKey] ??
        'ℹ️ Cambio automático de $fuenteAnterior → $nuevaFuente';
    _autoDescPendiente  = msg;

    debugPrint('[SmartRules] 🔄 $fuenteAnterior → $nuevaFuente ($faultKey)');

    return s.copyWith(
      activeSource  : nuevaFuente,
      detectedFault : limpiarFailover ? '' : faultKey,
      failoverActive: !limpiarFailover,
    );
  }

  void _enviarComando(String comando, String valor) {
    debugPrint('[SmartRules] 📤 AUTO-CMD: $comando = $valor');
    _repo.sendCommand(comando, valor);
  }

  String? getFaultMessage(String faultKey) => _faultMessages[faultKey];
}

// ── Provider ─────────────────────────────────────────────────────────────────
// Definido en lib/domain/providers.dart para evitar dependencia circular.
// Ver: smartRulesProvider en providers.dart
