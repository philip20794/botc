import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/custom_script_import_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('uses the app dark-purple theme for custom script import',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider(create: (_) => CharacterService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomScriptImportScreen(),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF4a3b5e));
    expect(theme.brightness, Brightness.dark);
    expect(theme.cardTheme.color, const Color(0xFF6f678a));
    expect(theme.dialogTheme.backgroundColor, const Color(0xFF6f678a));
  });
}
