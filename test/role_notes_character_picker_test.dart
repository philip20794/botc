import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_character_picker_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Role Notes reuses the grouped selector and only saves on assign',
      (tester) async {
    late CharacterService characters;
    late GameStateService game;
    late RoleNotesService notes;
    late SettingsService settings;
    late ScriptService script;

    await tester.runAsync(() async {
      characters = CharacterService();
      game = GameStateService();
      notes = RoleNotesService();
      settings = SettingsService();
      script = ScriptService();
      await Future.wait([
        characters.init(),
        game.ready,
        notes.init(),
        settings.initialized,
        script.ready,
      ]);
      await characters.loadAllCharactersFromJson(const Locale('en'));
      game.playerNames = ['Alice'];
      final chef = characters.allCharacters
          .singleWhere((character) => character.roleId == 'chef');
      await notes.setRolesForPlayer('Alice', [chef.image]);
    });

    Character role(String id) => characters.allCharacters
        .singleWhere((character) => character.roleId == id);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CharacterService>.value(value: characters),
          ChangeNotifierProvider<GameStateService>.value(value: game),
          ChangeNotifierProvider<RoleNotesService>.value(value: notes),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<ScriptService>.value(value: script),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final selected = await Navigator.push<List<String>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const RoleNotesCharacterPickerScreen(playerName: 'Alice'),
                    ),
                  );
                  if (selected != null) {
                    await notes.setRolesForPlayer('Alice', selected);
                  }
                },
                child: const Text('Open Role Notes picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openPicker() async {
      await tester.tap(find.text('Open Role Notes picker'));
      await tester.pumpAndSettle();
      expect(find.byType(RoleNotesCharacterPickerScreen), findsOneWidget);
      expect(find.byType(SelectCharacterComponent), findsOneWidget);
    }

    Finder avatar(String id) => find.byWidgetPredicate((widget) =>
        widget is CharacterAvatar && widget.character.roleId == id);

    Future<void> tapRole(String id) async {
      final finder = avatar(id);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
    }

    String count() => tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-selection-count')),
    ).data!;

    await openPicker();
    expect(count(), '1/4');
    expect(tester.widget<CharacterAvatar>(avatar('chef')).isSelected, isTrue);

    // Tap deselects immediately; new selections use the same white outline
    // and grouped grid as game setup.
    await tapRole('chef');
    expect(count(), '0/4');
    expect(tester.widget<CharacterAvatar>(avatar('chef')).isSelected, isFalse);
    for (final roleId in ['empath', 'monk', 'washerwoman', 'librarian']) {
      await tapRole(roleId);
      expect(tester.widget<CharacterAvatar>(avatar(roleId)).isSelected, isTrue);
    }
    expect(count(), '4/4');

    await tapRole('investigator');
    expect(count(), '4/4');
    expect(tester.widget<CharacterAvatar>(avatar('investigator')).isSelected,
        isFalse);

    await tester.tap(find.byKey(const ValueKey('role-notes-cancel-selection')));
    await tester.pumpAndSettle();
    expect(notes.roleImagesFor('Alice'), [role('chef').image]);

    // Reopening restores saved notes. Assign persists the new four roles.
    await openPicker();
    expect(count(), '1/4');
    expect(tester.widget<CharacterAvatar>(avatar('chef')).isSelected, isTrue);
    await tapRole('chef');
    for (final roleId in ['empath', 'monk', 'washerwoman', 'librarian']) {
      await tapRole(roleId);
    }
    await tester.tap(find.byKey(const ValueKey('role-notes-assign-selection')));
    await tester.pumpAndSettle();
    expect(notes.roleImagesFor('Alice'), [
      role('empath').image,
      role('monk').image,
      role('washerwoman').image,
      role('librarian').image,
    ]);
    expect(find.byType(RoleNotesCharacterPickerScreen), findsNothing);
  });
}
