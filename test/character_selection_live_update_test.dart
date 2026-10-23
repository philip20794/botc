import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('setup selection highlights and unhighlights without reopening',
      (tester) async {
    late CharacterService characters;
    late GameStateService game;
    late SettingsService settings;
    await tester.runAsync(() async {
      characters = CharacterService();
      game = GameStateService();
      settings = SettingsService();
      await Future.wait([
        characters.init(),
        game.ready,
        settings.initialized,
      ]);
      await characters.loadAllCharactersFromJson(const Locale('en'));
    });
    game.playerNames = List.generate(5, (i) => 'Player $i');
    final chef = characters.allCharacters
        .singleWhere((character) => character.roleId == 'chef');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CharacterService>.value(value: characters),
          ChangeNotifierProvider<GameStateService>.value(value: game),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SelectCharacterComponent(
              charactersToChooseFrom: [chef],
              onConfirm: () {},
              title: 'Selection',
              confirmButtonText: 'Continue',
              isForSetupGame: true,
              needToConfirm: false,
              showBackground: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final avatar = find.byType(CharacterAvatar);
    final outline = find.byKey(
        const ValueKey('character-avatar-highlight-outline'));
    expect(tester.widget<CharacterAvatar>(avatar).isSelected, isFalse);
    expect(outline, findsNothing);

    await tester.tap(avatar);
    await tester.pump();
    expect(characters.gameCharacters.where(
        (character) => character.roleId == 'chef'), hasLength(1));
    expect(tester.widget<CharacterAvatar>(avatar).isSelected, isTrue);
    expect(outline, findsOneWidget);

    await tester.tap(avatar);
    await tester.pump();
    expect(characters.gameCharacters.where(
        (character) => character.roleId == 'chef'), isEmpty);
    expect(tester.widget<CharacterAvatar>(avatar).isSelected, isFalse);
    expect(outline, findsNothing);
  });
}
