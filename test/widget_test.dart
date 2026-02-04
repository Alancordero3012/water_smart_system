import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_smart_system/data/services/preferences_service.dart';
import 'package:water_smart_system/main.dart';

void main() {
  testWidgets('App renders Dashboard without crashing', (
    WidgetTester tester,
  ) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const WaterSmartApp(),
      ),
    );

    // Trigger frame
    await tester.pumpAndSettle();

    // Verify Dashboard is present
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Niveles de Agua'), findsOneWidget);
  });
}
