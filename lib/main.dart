import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/services/preferences_service.dart';
import 'ui/shell/app_shell.dart';
import 'ui/alerts/alert_wrapper.dart';
import 'ui/theme/app_theme.dart';
import 'ui/auth/login_screen.dart';
import 'domain/auth_provider.dart';

/// Entry point — lightweight, no process spawning.
///
/// The backend (index.js + simulador.js) must be started manually before
/// launching the app:
///   cd backend_iot
///   node index.js        # Terminal 1
///   node simulador.js    # Terminal 2
///
/// The app connects to HiveMQ Cloud immediately on startup and waits for
/// MQTT data. The Bridge Health banner in the dashboard shows connection status.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const WaterSmartApp(),
    ),
  );
}

class WaterSmartApp extends StatelessWidget {
  const WaterSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Smart System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      builder: (context, child) => AlertWrapper(child: child),
      home: const _AuthGate(),
    );
  }
}

// ── Auth Gate — shows login or app depending on auth state ────────────────────

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: isAuthenticated
          ? const AppShell(key: ValueKey('shell'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
