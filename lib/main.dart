import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/services/preferences_service.dart';
import 'ui/shell/app_shell.dart';
import 'ui/alerts/alert_wrapper.dart';
import 'ui/theme/app_theme.dart';
import 'ui/auth/login_screen.dart';
import 'domain/auth_provider.dart';

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

// ── Auth Gate ─────────────────────────────────────────────────────────────────
// Muestra splash mientras verifica la sesión guardada,
// luego decide entre LoginScreen y AppShell.

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Verificando sesión guardada
    if (auth.isLoading) {
      return const _SplashScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: auth.isAuthenticated
          ? const AppShell(key: ValueKey('shell'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF090E1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded,
                color: Color(0xFF00E5FF), size: 48),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00E5FF),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'WATER SMART SYSTEM',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
