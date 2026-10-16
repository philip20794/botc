import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows imported scripts and their management actions',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;
    await scripts.upsertScript(BotcScript(
      id: 'custom:ui-test',
      name: 'Imported UI test',
      author: 'Tester',
      roleIds: const ['imp'],
    ));
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
          home: const Scaffold(
              body: Center(child: SelectGameset(disabled: false))),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Manage scripts'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Import script'), findsOneWidget);
    expect(find.text('Imported UI test'), findsOneWidget);
    expect(find.byTooltip('Delete script'), findsOneWidget);
    final managerTheme = Theme.of(tester.element(find.text('Import script')));
    expect(managerTheme.brightness, Brightness.dark);
    expect(
      managerTheme.textTheme.titleMedium?.color,
      GrimoireColors.ivory,
    );
    expect(
      managerTheme.listTileTheme.subtitleTextStyle?.color,
      GrimoireColors.secondaryText,
    );
  });

  testWidgets('keeps selector and management action usable in separate columns',
      (tester) async {
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SelectGameset(
                      disabled: false,
                      scriptWidth: constraints.maxWidth,
                      showManagementAction: false,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 48,
                  child: SelectGameset(
                    disabled: false,
                    showSelector: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byTooltip('Manage scripts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
