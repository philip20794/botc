import 'package:blood_on_the_clocktower/components/fabled_token.dart';
import 'package:blood_on_the_clocktower/components/select_language.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
import 'package:blood_on_the_clocktower/screens/settings_character_circle.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character role(String id, Fraction fraction) => Character(
      id: id,
      roleId: id,
      name: id,
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_$id',
      fraction: fraction,
      tokens: const [],
      wakeUpEveryNight: false,
      wakeUpAtFirstNight: false,
      gameset: const [Gameset.trouble_brewing],
      nightStateNumbersFirstNight: const [],
      nightStateNumbersOtherNights: const [],
      tipsAndTricks: const [],
      bluffs: const [],
    );

Widget app(Widget child, {
  required GameStateService game,
  required CharacterService characters,
  LanguageService? language,
  SettingsService? settings,
}) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: characters),
        if (language != null) ChangeNotifierProvider.value(value: language),
        if (settings != null) ChangeNotifierProvider.value(value: settings),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('player screen adds, reorders and deletes players', (tester) async {
    final game = GameStateService();
    await game.ready;
    final characters = CharacterService();
    await characters.init();
    await tester.pumpWidget(app(PlayernameScreen(), game: game, characters: characters));

    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Bob');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(game.playerNames, orderedEquals(['Alice', 'Bob']));

    await tester.drag(find.byIcon(Icons.drag_handle).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(game.playerNames, orderedEquals(['Bob', 'Alice']));

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pump();
    expect(game.playerNames, orderedEquals(['Alice']));
  });

  testWidgets('language dropdown updates the service immediately', (tester) async {
    final game = GameStateService();
    await game.ready;
    final characters = CharacterService();
    await characters.init();
    final language = LanguageService();
    await language.initialized;
    await tester.pumpWidget(app(const Scaffold(body: Center(child: SelectLanguage())), game: game, characters: characters, language: language));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pump();
    await tester.tap(find.text('Deutsch').last);
    await tester.pump();
    expect(language.locale, const Locale('de'));
  });

  testWidgets('layout slider updates its service and fabled token removes on second tap', (tester) async {
    final game = GameStateService();
    await game.ready;
    final characters = CharacterService();
    await characters.init();
    final settings = SettingsService();
    await settings.initialized;
    final fabled = role('angel', Fraction.fabled);
    characters.addCharacter(fabled);
    await tester.pumpWidget(app(SettingsCharacterCircle(), game: game, characters: characters, settings: settings));
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    expect(settings.characterKnobSize, isNot(90));

    await tester.pumpWidget(app(Scaffold(body: Center(child: FabledToken(character: fabled))), game: game, characters: characters, settings: settings));
    await tester.longPress(find.byType(FabledToken));
    await tester.pump();
    await tester.tap(find.byType(FabledToken));
    await tester.pump();
    expect(characters.gameCharacters, isEmpty);
  });
}
