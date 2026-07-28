import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'preferences_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WeatherService — Pronóstico de lluvia via Open-Meteo (sin API key)
//
// Consulta la API gratuita de Open-Meteo con las coordenadas configuradas en
// Settings y devuelve la probabilidad máxima de lluvia en las próximas 12h.
// El resultado se cachea por 1 hora para no saturar la API.
// ─────────────────────────────────────────────────────────────────────────────

class WeatherForecast {
  final double maxRainProbabilityNext12h; // 0–100
  final DateTime fetchedAt;

  const WeatherForecast({
    required this.maxRainProbabilityNext12h,
    required this.fetchedAt,
  });

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes > 60;

  bool get rainLikely => maxRainProbabilityNext12h >= 60.0;
}

class WeatherService {
  final PreferencesService _preferences;
  WeatherForecast? _cached;

  WeatherService(this._preferences);

  /// Devuelve el pronóstico de lluvia para las próximas 12h.
  /// Usa caché de 1h para no spamear la API.
  Future<WeatherForecast> getForecast() async {
    if (_cached != null && !_cached!.isStale) {
      return _cached!;
    }

    final lat = _preferences.weatherLatitude;
    final lon = _preferences.weatherLongitude;

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=precipitation_probability'
      '&forecast_days=1'
      '&timezone=auto',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final hourly = data['hourly'] as Map<String, dynamic>?;
        final probabilities =
            (hourly?['precipitation_probability'] as List?)
                ?.map((v) => (v as num).toDouble())
                .toList() ??
            [];

        // Tomar las próximas 12 horas desde ahora
        final currentHour = DateTime.now().hour;
        final next12 = probabilities
            .skip(currentHour)
            .take(12)
            .toList();

        final maxProb = next12.isEmpty
            ? 0.0
            : next12.reduce((a, b) => a > b ? a : b);

        _cached = WeatherForecast(
          maxRainProbabilityNext12h: maxProb,
          fetchedAt: DateTime.now(),
        );
        debugPrint(
            '[WeatherService] 🌦️ Prob. lluvia próx. 12h: ${maxProb.toStringAsFixed(0)}% ($lat, $lon)');
        return _cached!;
      } else {
        debugPrint(
            '[WeatherService] ⚠️ API error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[WeatherService] ⚠️ Error consultando Open-Meteo: $e');
    }

    // Fallback: si falla, devolver pronóstico neutro (no bloquear operación)
    return WeatherForecast(
      maxRainProbabilityNext12h: 0.0,
      fetchedAt: DateTime(2000),
    );
  }

  /// Shortcut: ¿hay alta probabilidad de lluvia en las próximas 12h?
  Future<bool> isRainLikelyNext12h() async {
    final forecast = await getForecast();
    return forecast.rainLikely;
  }

  /// Fuerza actualización del caché.
  void invalidateCache() => _cached = null;
}

// ── Providers ─────────────────────────────────────────────────────────────────
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return WeatherService(prefs);
});

/// Provider asíncrono para el forecast actual (usado en Settings UI).
final weatherForecastProvider = FutureProvider<WeatherForecast>((ref) async {
  final svc = ref.watch(weatherServiceProvider);
  return svc.getForecast();
});
