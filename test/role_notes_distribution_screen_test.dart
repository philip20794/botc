import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Role Notes centre display updates when the player list changes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final scripts = ScriptService();
    final game = GameStateService(scriptService: scripts);
    final characters = CharacterService();
    final language = LanguageService();
    final notes = RoleNotesService();
    final settings = SettingsService();

    await Future.wait([
      game.ready,
      scripts.ready,
      characters.init(),
      language.initialized,
      notes.init(),
      settings.initialized,
    ]);
    game.playerNames = List.generate(12, (index) => 'Player ${index + 1}');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: characters),
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoleNotesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-notes-standard-distribution')),
        findsOneWidget);
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-townsfolk-count'))).data, '7');
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-outsider-count'))).data, '2');
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-minion-count'))).data, '2');

    await game.removePlayerName('Player 12');
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-outsider-count'))).data, '1');

    for (final name in game.playerNames.skip(4).toList()) {
      await game.removePlayerName(name);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-notes-standard-distribution')),
        findsNothing);
  });
}
