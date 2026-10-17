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

  testWidgets('selection uses a stepped Slider, not a number TextField',
      (tester) async {
    late CharacterService characters;
    late GameStateService game;
    late SettingsService settings;
    await tester.runAsync(() async {
      characters = CharacterService();
      game = GameStateService();
      settings = SettingsService();
      await Future.wait([
        characters.init(), game.ready, settings.initialized,
      ]);
    });
    game.playerNames = List.generate(10, (i) => 'Player $i');
    final idiot = characters.allCharacters.singleWhere(
        (character) => character.roleId == 'villageidiot');
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
              charactersToChooseFrom: [idiot],
              onConfirm: () {},
              title: 'Selection',
              confirmButtonText: 'Continue',
              isForSetupGame: true,
              showBackground: false,
              needToConfirm: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(CharacterAvatar).first);
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('exemplar-count-slider'));
    expect(slider, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.widget<Slider>(slider).divisions, 2);
    await tester.drag(slider, const Offset(130, 0));
    await tester.pump();
    final selected = int.parse(
        tester.widget<Text>(
          find.byKey(const ValueKey('exemplar-count-value'))).data!);
    expect([1, 2, 3], contains(selected));
    await tester.tap(find.byKey(const ValueKey('confirm-exemplar-count')));
    await tester.pumpAndSettle();
    expect(characters.gameCharacters.where(
        (character) => character.roleId == 'villageidiot').length, selected);
  });
}
