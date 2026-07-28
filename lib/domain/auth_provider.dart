import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Auth state ────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false); // false = not authenticated

  static const _adminUser = 'admin';
  static const _adminPass = 'WaterSmart2024';

  /// Returns true if login succeeded.
  bool login(String username, String password) {
    if (username.trim() == _adminUser && password == _adminPass) {
      state = true;
      return true;
    }
    return false;
  }

  void logout() => state = false;
}

final authProvider = StateNotifierProvider<AuthNotifier, bool>(
  (ref) => AuthNotifier(),
);
