import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('player names add, remove, reorder and persist', () async {
    final game = GameStateService();
    await game.ready;
    await game.addPlayerName('Alice');
    await game.addPlayerName('Bob');
    await game.addPlayerName('Cara');
    await game.addPlayerName('');
    await game.reorderPlayerNames(0, 3);
    await game.removePlayerName('Bob');

    expect(game.playerNames, orderedEquals(['Cara', 'Alice']));
    final restored = GameStateService();
    await restored.ready;
    expect(restored.playerNames, orderedEquals(['Cara', 'Alice']));

    await restored.clearAllPlayerNames();
    expect((await SharedPreferences.getInstance()).getString('player_names'),
        '[]');
  });

  test('factory reset clears persisted player state', () async {
    final game = GameStateService();
    await game.ready;
    await game.addPlayerName('Alice');
    await game.factoryReset();
    expect(game.playerNames, isEmpty);
    expect((await SharedPreferences.getInstance()).containsKey('player_names'),
        isFalse);
  });

  test('role notes de-duplicate, limit, move, delete and restore', () async {
    final notes = RoleNotesService();
    await notes.init();
    await notes.setRolesForPlayer('Alice', ['a', 'a', 'b', 'c', 'd', 'e']);
    expect(notes.roleImagesFor('Alice'), orderedEquals(['a', 'b', 'c', 'd']));
    await notes.removeRoleFromPlayer('Alice', 'b');
    await notes.setRolesForPlayer('Bob', notes.roleImagesFor('Alice'));
    expect(notes.duplicateRoleImages().keys, containsAll(['a', 'c', 'd']));
    await notes.clearRolesForPlayer('Alice');
    expect(notes.roleImagesFor('Bob'), orderedEquals(['a', 'c', 'd']));

    final restored = RoleNotesService();
    await restored.init();
    expect(restored.roleImagesFor('Bob'), orderedEquals(['a', 'c', 'd']));
    await restored.clearAllRoleNotes();
    expect(restored.hasAnyRoleNotes(), isFalse);
  });

  test('role note positions clamp, save and restore', () async {
    final notes = RoleNotesService();
    await notes.init();
    await notes.setPlayerPosition(
        'Alice', const Offset(500, -1), const Size(100, 100), 20);
    expect(notes.positionOf('Alice'), const Offset(80, 0));
    final restored = RoleNotesService();
    await restored.init();
    expect(restored.positionOf('Alice'), const Offset(80, 0));
  });

  test('language ignores unsupported locales and persists supported locale',
      () async {
    final language = LanguageService();
    await language.initialized;
    await language.setLocale(const Locale('de'));
    await language.setLocale(const Locale('fr'));
    expect(language.locale, const Locale('de'));
    final restored = LanguageService();
    await restored.initialized;
    expect(restored.locale, const Locale('de'));
  });

  test('layout reset restores offsets and survives a service restart',
      () async {
    final settings = SettingsService();
    await settings.initialized;
    await settings.setTokenOffsetX(2);
    await settings.setTokenOffsetY(3);
    await settings.setCharacterKnobSize(11);
    await settings.resetSettings();
    expect(settings.tokenOffsetX, 45);
    expect(settings.tokenOffsetY, 30);
    expect(settings.characterKnobSize, 100);
    final restored = SettingsService();
    await restored.initialized;
    expect(restored.tokenOffsetX, 45);
    expect(restored.tokenOffsetY, 30);
  });

  test('character selection prevents duplicate roles and counts factions',
      () async {
    final characters = CharacterService();
    await characters.init();
    await characters.loadAllCharactersFromJson(const Locale('en'));
    final monk = characters.allCharacters
        .firstWhere((character) => character.roleId == 'monk');
    final imp = characters.allCharacters
        .firstWhere((character) => character.roleId == 'imp');
    characters.addCharacter(monk);
    characters.addCharacter(imp);
    characters.addCharacter(monk);

    expect(characters.getFractionCount(Fraction.townsfolk), 1);
    expect(characters.getFractionCount(Fraction.demon), 1);
    expect(characters.gameCharacters, hasLength(2));
    characters.removeCharacter(monk);
    expect(characters.getFractionCount(Fraction.townsfolk), 0);
  });
}
