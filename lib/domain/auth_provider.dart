import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/services/preferences_service.dart';

// ── Constantes ────────────────────────────────────────────────────────────────

/// URL base del backend. En web usa la IP pública cuando se deploya.
/// Ajustar a la URL de Railway cuando se suba.
const String kBackendUrl = kIsWeb
    ? 'http://localhost:3001'
    : 'http://localhost:3001';

const String _kJwtKey     = 'auth_jwt_token';
const String _kUserKey    = 'auth_user_json';

// ── Modelo de usuario ─────────────────────────────────────────────────────────

class AuthUser {
  final int    id;
  final String nombre;
  final String email;
  final String rol;

  const AuthUser({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id:     (j['id'] as num).toInt(),
        nombre: j['nombre'] as String,
        email:  j['email']  as String,
        rol:    j['rol']    as String,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'nombre': nombre, 'email': email, 'rol': rol};

  bool get isAdmin => rol == 'admin';
}

// ── Estado de auth ────────────────────────────────────────────────────────────

class AuthState {
  final bool       isAuthenticated;
  final bool       isLoading;        // verificando sesión guardada al inicio
  final AuthUser?  user;
  final String?    token;
  final String?    error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading       = true,
    this.user,
    this.token,
    this.error,
  });

  AuthState copyWith({
    bool?      isAuthenticated,
    bool?      isLoading,
    AuthUser?  user,
    String?    token,
    String?    error,
    bool       clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading:       isLoading       ?? this.isLoading,
      user:            user            ?? this.user,
      token:           token           ?? this.token,
      error:           clearError ? null : (error ?? this.error),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final SharedPreferences _prefs;

  AuthNotifier(this._prefs) : super(const AuthState()) {
    _restoreSession();
  }

  // ── Restaurar sesión al inicio de la app ──────────────────────────────────

  Future<void> _restoreSession() async {
    final token = _prefs.getString(_kJwtKey);
    if (token == null) {
      state = const AuthState(isLoading: false, isAuthenticated: false);
      return;
    }

    try {
      final resp = await http.get(
        Uri.parse('$kBackendUrl/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        state = AuthState(
          isAuthenticated: true,
          isLoading:       false,
          user:            user,
          token:           token,
        );
      } else {
        // Token expirado o inválido
        await _clearStoredSession();
        state = const AuthState(isLoading: false, isAuthenticated: false);
      }
    } catch (_) {
      // Backend no disponible — mantener la sesión local como válida
      // para no bloquear al usuario si el backend está caído temporalmente
      final userJson = _prefs.getString(_kUserKey);
      if (userJson != null) {
        final user = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        state = AuthState(
          isAuthenticated: true,
          isLoading:       false,
          user:            user,
          token:           token,
        );
      } else {
        state = const AuthState(isLoading: false, isAuthenticated: false);
      }
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final resp = await http.post(
        Uri.parse('$kBackendUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email.trim().toLowerCase(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body  = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = body['token'] as String;
        final user  = AuthUser.fromJson(body['user'] as Map<String, dynamic>);

        // Guardar en SharedPreferences
        await _prefs.setString(_kJwtKey,  token);
        await _prefs.setString(_kUserKey, jsonEncode(user.toJson()));

        state = AuthState(
          isAuthenticated: true,
          isLoading:       false,
          user:            user,
          token:           token,
        );
        return true;
      } else {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          error:     body['error'] as String? ?? 'Credenciales inválidas',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     'No se pudo conectar al servidor',
      );
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final token = state.token;
    // Notificar al backend (best-effort, no bloqueante)
    if (token != null) {
      http.post(
        Uri.parse('$kBackendUrl/api/auth/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).ignore();
    }
    await _clearStoredSession();
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  Future<void> _clearStoredSession() async {
    await _prefs.remove(_kJwtKey);
    await _prefs.remove(_kUserKey);
  }

  // ── Crear usuario (solo admin) ─────────────────────────────────────────────

  Future<Map<String, dynamic>> createUser({
    required String nombre,
    required String email,
    required String password,
    String rol = 'operador',
  }) async {
    if (state.token == null) return {'error': 'No autenticado'};

    try {
      final resp = await http.post(
        Uri.parse('$kBackendUrl/api/usuarios'),
        headers: {
          'Authorization': 'Bearer ${state.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nombre':   nombre,
          'email':    email,
          'password': password,
          'rol':      rol,
        }),
      ).timeout(const Duration(seconds: 10));

      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }

  /// Listar usuarios del sistema (solo admin)
  Future<List<Map<String, dynamic>>> getUsuarios() async {
    if (state.token == null) return [];
    try {
      final resp = await http.get(
        Uri.parse('$kBackendUrl/api/usuarios'),
        headers: {
          'Authorization': 'Bearer ${state.token}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['usuarios'] as List);
      }
    } catch (_) {}
    return [];
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AuthNotifier(prefs);
  },
);
