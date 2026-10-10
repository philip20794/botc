import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/screens/all_characters_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
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

  testWidgets(
      'keeps the script selector within a narrow all-characters app bar',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scripts = ScriptService();
    await scripts.ready;
    await scripts.upsertScript(BotcScript(
      id: 'custom:long-name',
      name: 'A deliberately very long custom script name',
      roleIds: const ['imp'],
    ));
    await scripts.selectScript('custom:long-name', gameIsRunning: false);
    final gameState = GameStateService(scriptService: scripts);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: gameState),
          ChangeNotifierProvider(create: (_) => CharacterService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AllCharactersScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Manage scripts'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Import script'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the German import item within a 360 pixel menu',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scripts = ScriptService();
    await scripts.ready;
    final gameState = GameStateService(scriptService: scripts);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: gameState),
          ChangeNotifierProvider(create: (_) => CharacterService()),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AllCharactersScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Skript importieren'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
