import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/services/preferences_service.dart';
import '../repositories/water_data_repository.dart';
import '../models/water_system_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartRulesService — Motor de Reglas Inteligentes (v2)
//
// CAMBIOS v2:
//  [GAP 1]  Umbrales adaptativos: carga P10/P90 del backend; usa estáticos como
//            fallback si no hay suficiente historial (< 50 muestras).
//  [GAP 5]  Per-rule toggles: cada regla verifica si está habilitada en prefs.
//  [GAP 6]  Buffer de presión + detección de tendencia (dP/dt > umbral).
//  [GAP 7]  Correlación nivel-flujo: nivel cayendo rápido + flujo=0 → diagnóstico.
//  [GAP 10] Logs de decisión enriquecidos con valores numéricos actuales.
//
// PRINCIPIO CENTRAL (sin cambios):
//   Si hay falla en la fuente activa → cambiar a la fuente de respaldo.
//   Solo apagar todo si AMBAS fuentes están no disponibles.
// ─────────────────────────────────────────────────────────────────────────────

/// Punto en el buffer de tendencias.
class _DataPoint {
  final double value;
  final DateTime time;
  _DataPoint(this.value, this.time);
}

class SmartRulesService {
  final PreferencesService _preferences;
  final WaterDataRepository _repo;

  SmartRulesService(this._preferences, this._repo);

  // ── Umbrales estáticos (fallback si no hay historial suficiente) ──────────
  // ⚠️ Ajustados para presentación: coinciden con index.js para evitar cortes falsos.
  static const double _staticMinPressure    = 3.0;    // PSI (antes 10 — demasiado agresivo sin sensor)
  static const double _staticMaxPressure    = 80.0;   // PSI (antes 45)
  static const double _staticMinFlowAnomaly = 5.0;    // L/min (antes 0.5 — disparaba con flujo=0)
  static const int    _faultWindowSec       = 120;    // s (antes 30 — muy poco tiempo para estabilizar)
  static const int    _minSamplesForAdaptive = 50; // mínimo de muestras para usar umbrales adaptativos

  // ── Umbrales adaptativos (se cargan desde /api/thresholds) ───────────────
  double _adaptiveMinPressure    = _staticMinPressure;
  double _adaptiveMaxPressure    = _staticMaxPressure;
  double _adaptiveMinFlowAnomaly = _staticMinFlowAnomaly;
  bool   _adaptiveLoaded         = false;
  DateTime? _lastThresholdLoad;

  static const double _minTankLevel   = 5.0;   // % (antes 15 — apagaba con tanques casi llenos)
  static const _failoverCooldown      = Duration(seconds: 90);

  // ── Estado interno ────────────────────────────────────────────────────────
  DateTime? _flowZeroSince;
  DateTime? _presionBajaSince;
  DateTime? _lastFailover;
  String    _autoDescPendiente = '';

  // ── [GAP 6] Buffer circular de lecturas de presión ────────────────────────
  final List<_DataPoint> _pressureBuffer = [];
  final List<_DataPoint> _levelBuffer    = [];
  static const int _bufferSize = 10;

  // ── Cooldown para la alerta de tendencia (no spamear) ────────────────────
  DateTime? _lastTendenciaAlert;

  // ── Mapa de mensajes legibles por regla ──────────────────────────────────
  static const Map<String, String> _faultMessages = {
    'rotura_tuberia_calle'             : '⛔ Rotura/bloqueo en línea CALLE — cambiando a LLUVIA',
    'rotura_tuberia_lluvia'            : '⛔ Rotura/bloqueo en línea LLUVIA — cambiando a CALLE',
    'fuga_detectada'                   : '⚠️ Fuga detectada — flujo activo con sistema apagado',
    'presion_critica_alta_calle'       : '⚠️ Presión muy alta en CALLE — bomba detenida',
    'presion_critica_alta_lluvia'      : '⚠️ Presión muy alta en LLUVIA — bomba detenida',
    'presion_baja_calle'               : '⚠️ Presión baja en CALLE — cambiando a LLUVIA',
    'presion_baja_lluvia'              : '⚠️ Presión baja en LLUVIA — cambiando a CALLE',
    'sensor_inconsistente_calle'       : '🔧 Sensor inconsistente en Tanque CALLE — verificar hardware',
    'sensor_inconsistente_lluvia'      : '🔧 Sensor inconsistente en Tanque LLUVIA — verificar hardware',
    'sin_fuente_disponible'            : '🚨 CRÍTICO: Ambas fuentes no disponibles — sistema detenido',
    'failover_automatico'              : 'ℹ️ Failover automático ejecutado por el sistema',
    'fuente_prioritaria_restaurada'    : 'ℹ️ Fuente prioritaria restaurada — volviendo al origen preferido',
    'tendencia_presion'                : '⚡ Presión subiendo rápido — posible golpe de ariete',
    'correlacion_nivel_flujo'          : '🔧 Nivel cae pero flujo=0 — posible sensor de caudal atascado',
  };

  // ── API pública ───────────────────────────────────────────────────────────

  /// Carga umbrales adaptativos desde el backend (llama a /api/thresholds).
  /// Debe invocarse una vez al iniciar, y el SmartRulesService usará los valores
  /// dinámicos en adelante. Si falla, los estáticos permanecen como fallback.
  Future<void> loadAdaptiveThresholds(String bridgeBaseUrl) async {
    // No recargar si ya cargamos en la última hora
    if (_lastThresholdLoad != null &&
        DateTime.now().difference(_lastThresholdLoad!).inMinutes < 60) {
      return;
    }
    try {
      final url = Uri.parse('$bridgeBaseUrl/api/thresholds');
      final resp = await http.get(url).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final pressure = data['pressure'] as Map<String, dynamic>?;
        final flow     = data['flow']     as Map<String, dynamic>?;

        final sampleCount = pressure?['sampleCount'] as int? ?? 0;
        if (sampleCount >= _minSamplesForAdaptive) {
          _adaptiveMinPressure    = (pressure?['adaptiveMin'] as num?)?.toDouble() ?? _staticMinPressure;
          _adaptiveMaxPressure    = (pressure?['adaptiveMax'] as num?)?.toDouble() ?? _staticMaxPressure;
          _adaptiveMinFlowAnomaly = (flow?['adaptiveMin']    as num?)?.toDouble() ?? _staticMinFlowAnomaly;
          _adaptiveLoaded = true;
          _lastThresholdLoad = DateTime.now();
          debugPrint('[SmartRules] 📊 Umbrales adaptativos cargados: '
              'presión [$_adaptiveMinPressure–$_adaptiveMaxPressure] PSI, '
              'flujo min $_adaptiveMinFlowAnomaly L/min '
              '(n=$sampleCount)');
        } else {
          debugPrint('[SmartRules] ℹ️ Pocas muestras ($sampleCount < $_minSamplesForAdaptive) — usando umbrales estáticos');
        }
      }
    } catch (e) {
      debugPrint('[SmartRules] ⚠️ No se pudo cargar /api/thresholds: $e — usando fallback estático');
    }
  }

  // Getters de umbrales efectivos (adaptativos o estáticos)
  double get _minPressure    => _adaptiveLoaded ? _adaptiveMinPressure    : _staticMinPressure;
  double get _maxPressure    => _adaptiveLoaded ? _adaptiveMaxPressure    : _staticMaxPressure;
  double get _minFlowAnomaly => _adaptiveLoaded ? _adaptiveMinFlowAnomaly : _staticMinFlowAnomaly;

  // ── [GAP 5] Helper: verificar si una regla está habilitada ───────────────
  bool _ruleEnabled(String ruleKey) => _preferences.isRuleEnabled(ruleKey);

  /// Evalúa todas las reglas sobre el estado actual.
  WaterSystemState evaluateRules(WaterSystemState s) {
    final pendingLog = _autoDescPendiente;
    _autoDescPendiente = '';

    WaterSystemState next = s.copyWith(
      autoActionLog: pendingLog,
      detectedFault: '',
      failoverActive: s.failoverActive,
    );

    next = _actualizarFuenteActiva(next);

    // [GAP 5] Cada regla verifica su toggle individual
    if (_ruleEnabled('sensor_inconsistente')) {
      next = _checkSensorInconsistente(next);
    }
    if (_ruleEnabled('fuga_agua')) {
      next = _checkFugaAgua(next);
    }
    if (_ruleEnabled('presion_alta')) {
      next = _checkPresionAlta(next);
    }
    // [GAP 6] Tendencia de presión
    if (_ruleEnabled('tendencia_presion')) {
      next = _checkTendenciaPresion(next);
    }
    if (_ruleEnabled('rotura_tuberia') || _ruleEnabled('presion_baja')) {
      next = _checkFallaFuente(next);
    }
    // [GAP 7] Correlación nivel-flujo
    if (_ruleEnabled('correlacion_nivel_flujo')) {
      next = _checkCorrelacionNivelFlujo(next);
    }
    if (_ruleEnabled('restaurar_fuente')) {
      next = _checkRestaurarFuente(next);
    }

    // Actualizar buffer de presión (para tendencias)
    _pushPressureBuffer(s.streetPressure);
    _pushLevelBuffer(
      s.activeSource == 'calle' ? s.streetTankLevel : s.rainTankLevel,
    );

    return next;
  }

  // ── Reglas privadas ───────────────────────────────────────────────────────

  WaterSystemState _actualizarFuenteActiva(WaterSystemState s) {
    if (s.isBombaCalleActive && s.isSolenoideCalleOpen) {
      return s.copyWith(activeSource: 'calle');
    }
    if (s.isBombaLluviaActive && s.isSoleLluviaOpen) {
      return s.copyWith(activeSource: 'lluvia');
    }
    return s;
  }

  WaterSystemState _checkSensorInconsistente(WaterSystemState s) {
    if (s.calleS100 && s.calleS0) {
      return s.copyWith(detectedFault: 'sensor_inconsistente_calle');
    }
    if (s.lluviaS100 && s.lluviaS0) {
      return s.copyWith(detectedFault: 'sensor_inconsistente_lluvia');
    }
    return s;
  }

  // [GAP 10] Fuga: log enriquecido con el valor de flujo actual
  WaterSystemState _checkFugaAgua(WaterSystemState s) {
    final sistemaCerrado = !s.isBombaCalleActive && !s.isBombaLluviaActive &&
                           !s.isSolenoideCalleOpen && !s.isSoleLluviaOpen;
    if (sistemaCerrado && s.flowRate > _minFlowAnomaly) {
      _autoDescPendiente =
          '⚠️ Fuga detectada — flujo ${s.flowRate.toStringAsFixed(2)} L/min '
          'con sistema apagado (umbral: ${_minFlowAnomaly.toStringAsFixed(1)} L/min)';
      return s.copyWith(detectedFault: 'fuga_detectada');
    }
    return s;
  }

  // [GAP 10] Presión alta: log con valor real y umbral activo
  WaterSystemState _checkPresionAlta(WaterSystemState s) {
    if (s.streetPressure > _maxPressure) {
      final fuenteActiva = s.activeSource;
      final faultKey = 'presion_critica_alta_$fuenteActiva';
      _enviarComando('bomba_$fuenteActiva', '0');
      _autoDescPendiente =
          '⚠️ Presión ${s.streetPressure.toStringAsFixed(1)} PSI > '
          '${_maxPressure.toStringAsFixed(0)} PSI en $fuenteActiva '
          '— bomba detenida automáticamente'
          '${_adaptiveLoaded ? " (umbral adaptativo)" : " (umbral estático)"}';
      debugPrint('[SmartRules] ⚠️ Presión alta — bomba $fuenteActiva detenida');
      return s.copyWith(detectedFault: faultKey);
    }
    return s;
  }

  // [GAP 6] Tendencia de presión: dP/dt > 2 PSI/s con presión > 70% del máximo
  WaterSystemState _checkTendenciaPresion(WaterSystemState s) {
    final dPdt = _getRateOfChange(_pressureBuffer); // PSI/segundo
    final alreadyAlerting = _lastTendenciaAlert != null &&
        DateTime.now().difference(_lastTendenciaAlert!).inSeconds < 60;

    if (!alreadyAlerting && dPdt > 2.0 && s.streetPressure > (_maxPressure * 0.75)) {
      _lastTendenciaAlert = DateTime.now();
      _autoDescPendiente =
          '⚡ Presión subiendo rápido (${dPdt.toStringAsFixed(1)} PSI/s) — '
          'actual: ${s.streetPressure.toStringAsFixed(1)} PSI. '
          'Posible golpe de ariete en ${s.activeSource}';
      debugPrint('[SmartRules] ⚡ Tendencia presión: ${dPdt.toStringAsFixed(2)} PSI/s');
      return s.copyWith(detectedFault: 'tendencia_presion');
    }
    return s;
  }

  // [GAP 7] Correlación: nivel cayendo rápido + flujo=0 → sensor atascado
  WaterSystemState _checkCorrelacionNivelFlujo(WaterSystemState s) {
    final sistemaActivo = s.isBombaCalleActive || s.isBombaLluviaActive;
    if (!sistemaActivo || _levelBuffer.length < 4) return s;

    final dNdt = _getRateOfChange(_levelBuffer); // %/segundo
    final dNdtPerMin = dNdt * 60; // %/minuto

    // Si nivel cae >2%/min pero flujo reporta casi 0 → sensor de caudal atascado
    if (dNdtPerMin < -2.0 && s.flowRate < 0.05) {
      debugPrint('[SmartRules] 🔧 Correlación: nivel cae ${dNdtPerMin.toStringAsFixed(2)}%/min pero flujo=0');
      _autoDescPendiente =
          '🔧 Nivel cayendo ${dNdtPerMin.abs().toStringAsFixed(1)}%/min '
          'pero flujo=${s.flowRate.toStringAsFixed(2)} L/min — '
          'posible sensor de caudal atascado (no es rotura)';
      return s.copyWith(
        detectedFault: 'correlacion_nivel_flujo',
        sensorFlujoAtascado: true,
      );
    }
    return s;
  }

  WaterSystemState _checkFallaFuente(WaterSystemState s) {
    final sistemaActivo = s.isBombaCalleActive || s.isBombaLluviaActive;
    if (!sistemaActivo) {
      _flowZeroSince    = null;
      _presionBajaSince = null;
      return s;
    }

    final fuenteActiva = s.activeSource;
    final now          = DateTime.now();
    bool  faltaDetectada = false;
    String faultKey      = '';

    // Regla rotura (flujo cero)
    if (_ruleEnabled('rotura_tuberia')) {
      final sistemaSolenoidAbierto = s.isSolenoideCalleOpen || s.isSoleLluviaOpen;
      if (sistemaSolenoidAbierto && s.flowRate < 0.1) {
        _flowZeroSince ??= now;
        final elapsed = now.difference(_flowZeroSince!).inSeconds;
        if (elapsed >= _faultWindowSec) {
          faltaDetectada = true;
          faultKey       = 'rotura_tuberia_$fuenteActiva';
          _autoDescPendiente =
              '⛔ Flujo=0 por ${elapsed}s con bomba activa en $fuenteActiva '
              '(Presión: ${s.streetPressure.toStringAsFixed(1)} PSI) '
              '— cambiando a fuente de respaldo';
          debugPrint('[SmartRules] ⛔ Flujo cero por ${elapsed}s — posible rotura en $fuenteActiva');
        }
      } else {
        _flowZeroSince = null;
      }
    }

    // Regla presión baja
    if (!faltaDetectada && _ruleEnabled('presion_baja') &&
        s.streetPressure < _minPressure && s.streetPressure > 0) {
      _presionBajaSince ??= now;
      final elapsed = now.difference(_presionBajaSince!).inSeconds;
      if (elapsed >= 20) {
        faltaDetectada = true;
        faultKey       = 'presion_baja_$fuenteActiva';
        _autoDescPendiente =
            '⚠️ Presión ${s.streetPressure.toStringAsFixed(1)} PSI < '
            '${_minPressure.toStringAsFixed(0)} PSI en $fuenteActiva por ${elapsed}s '
            '— cambiando a fuente de respaldo'
            '${_adaptiveLoaded ? " (umbral adaptativo)" : ""}';
        debugPrint('[SmartRules] ⚠️ Presión baja por ${elapsed}s — failover desde $fuenteActiva');
      }
    } else {
      _presionBajaSince = null;
    }

    if (!faltaDetectada) return s;

    return _ejecutarFailover(s, fuenteActiva, faultKey);
  }

  WaterSystemState _checkRestaurarFuente(WaterSystemState s) {
    if (!s.failoverActive) return s;

    final prioridad    = _preferences.prioritySource;
    final fuentePref   = prioridad == 'rain' ? 'lluvia' : 'calle';
    final nivelPref    = fuentePref == 'lluvia' ? s.rainTankLevel : s.streetTankLevel;
    final fuenteActiva = s.activeSource;

    if (fuenteActiva == fuentePref) {
      return s.copyWith(failoverActive: false);
    }

    final cooldownOk = _lastFailover == null ||
        DateTime.now().difference(_lastFailover!).inSeconds > 120;

    if (nivelPref > 20.0 && cooldownOk) {
      debugPrint('[SmartRules] ℹ️ Fuente prioritaria ($fuentePref) restaurada — volviendo');
      return _ejecutarCambioFuente(s, fuentePref, 'fuente_prioritaria_restaurada',
          limpiarFailover: true);
    }

    return s;
  }

  // ── Helpers de buffer (GAP 6) ──────────────────────────────────────────────

  void _pushPressureBuffer(double value) {
    _pressureBuffer.add(_DataPoint(value, DateTime.now()));
    if (_pressureBuffer.length > _bufferSize) _pressureBuffer.removeAt(0);
  }

  void _pushLevelBuffer(double value) {
    _levelBuffer.add(_DataPoint(value, DateTime.now()));
    if (_levelBuffer.length > _bufferSize) _levelBuffer.removeAt(0);
  }

  /// Calcula la tasa de cambio (unidad/segundo) entre el primer y último punto.
  double _getRateOfChange(List<_DataPoint> buf) {
    if (buf.length < 3) return 0;
    final oldest = buf.first;
    final newest = buf.last;
    final deltaT = newest.time.difference(oldest.time).inMilliseconds / 1000.0;
    if (deltaT <= 0) return 0;
    return (newest.value - oldest.value) / deltaT;
  }

  // ── Helpers de failover (sin cambios de lógica) ────────────────────────────

  WaterSystemState _ejecutarFailover(
      WaterSystemState s, String fuenteActual, String faultKey) {

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
      debugPrint('[SmartRules] 🚨 Sin fuente de respaldo — deteniendo todo');
      _enviarComando('bomba_calle',      '0');
      _enviarComando('solenoide_calle',  '0');
      _enviarComando('bomba_lluvia',     '0');
      _enviarComando('solenoide_lluvia', '0');
      _autoDescPendiente = '🚨 CRÍTICO: Tanque $fuenteRespaldo al '
          '${nivelRespaldo.toStringAsFixed(0)}% — ambas fuentes no disponibles';
      return s.copyWith(
        detectedFault : 'sin_fuente_disponible',
        failoverActive: false,
      );
    }

    return _ejecutarCambioFuente(s, fuenteRespaldo, faultKey, limpiarFailover: false);
  }

  WaterSystemState _ejecutarCambioFuente(
      WaterSystemState s, String nuevaFuente, String faultKey,
      {required bool limpiarFailover}) {

    final fuenteAnterior = s.activeSource;

    _enviarComando('bomba_$fuenteAnterior',     '0');
    _enviarComando('solenoide_$fuenteAnterior', '0');
    _enviarComando('bomba_$nuevaFuente',        '1');
    _enviarComando('solenoide_$nuevaFuente',    '1');

    _lastFailover     = DateTime.now();
    _flowZeroSince    = null;
    _presionBajaSince = null;

    // Si _autoDescPendiente no fue sobreescrito por la regla específica,
    // usar el mensaje genérico enriquecido.
    if (_autoDescPendiente.isEmpty) {
      final nivelNueva = nuevaFuente == 'lluvia' ? s.rainTankLevel : s.streetTankLevel;
      _autoDescPendiente =
          '🔄 $fuenteAnterior → $nuevaFuente | '
          'Nivel $nuevaFuente: ${nivelNueva.toStringAsFixed(0)}%';
    }

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

  /// Información de diagnóstico sobre el estado de los umbrales.
  String get thresholdInfo => _adaptiveLoaded
      ? 'Adaptativos: P=${_adaptiveMinPressure.toStringAsFixed(1)}–'
        '${_adaptiveMaxPressure.toStringAsFixed(1)} PSI, '
        'F≥${_adaptiveMinFlowAnomaly.toStringAsFixed(2)} L/min'
      : 'Estáticos (sin historial suficiente): '
        'P=$_staticMinPressure–$_staticMaxPressure PSI';
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Definido en lib/domain/providers.dart para evitar dependencia circular.
// Ver: smartRulesProvider en providers.dart

