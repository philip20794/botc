import 'dart:convert';
import 'dart:io';

import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<dynamic>> loadCatalog(String localeCode) async {
  final raw = await File('assets/characters/$localeCode.json').readAsString();
  return jsonDecode(raw) as List<dynamic>;
}

Character roleById(List<Character> catalog, String roleId) {
  return catalog.singleWhere((character) => character.roleId == roleId);
}

Map<String, dynamic> catalogEntry({
  required String name,
  required String descriptionShort,
  required String descriptionLong,
  required String howToRun,
  required String image,
  required String fraction,
  required List<dynamic> tokens,
  String help = '',
  List<dynamic> tipsAndTricks = const [],
  List<dynamic> bluffs = const [],
}) {
  return {
    'name': name,
    'descriptionShort': descriptionShort,
    'descriptionLong': descriptionLong,
    'howToRun': howToRun,
    'image': image,
    'fraction': fraction,
    'tokens': tokens,
    'wakeUpEveryNight': false,
    'wakeUpAtFirstNight': false,
    'gameset': ['trouble_brewing'],
    'nightStateNumbersFirstNight': <double>[],
    'nightStateNumbersOtherNights': <double>[],
    'tipsAndTricks': tipsAndTricks,
    'bluffs': bluffs,
    'help': help,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('German catalog falls back to every missing English role', () async {
    final english = await loadCatalog('en');
    final german = await loadCatalog('de');

    final merged = CharacterService.mergeLocalizedCatalog(english, german);

    expect(merged, hasLength(english.length));
    expect(
      merged.map((character) => character.roleId),
      orderedEquals(
        english
            .cast<Map<String, dynamic>>()
            .map((entry) => Character.fromJson(entry).roleId),
      ),
    );
    final englishBigwig = english.cast<Map<String, dynamic>>().singleWhere(
          (entry) => Character.fromJson(entry).roleId == 'bigwig',
        );
    expect(
      roleById(merged, 'bigwig').name,
      Character.fromJson(englishBigwig).name,
    );
  });

  test('required localized text falls back while optional empty fields remain',
      () {
    final english = catalogEntry(
      name: 'English role',
      descriptionShort: 'English ability',
      descriptionLong: 'English long description',
      howToRun: 'English storyteller instructions',
      help: 'English help',
      image: 'Icon_example',
      fraction: 'townsfolk',
      tokens: [
        {'name': 'English token', 'image': 'Icon_example', 'needsSetup': true},
      ],
      tipsAndTricks: ['English tip'],
      bluffs: ['English bluff'],
    )..['roleId'] = 'example';
    final german = {
      ...english,
      'name': 'Deutsche Rolle',
      'descriptionShort': 'Deutsche Fähigkeit',
      'descriptionLong': '',
      'howToRun': '',
      'help': '',
      'image': 'Icon_invalid_localized_variant',
      'fraction': 'demon',
      'gameset': ['experimental'],
      'wakeUpEveryNight': true,
      'nightStateNumbersFirstNight': [99.0],
      'tokens': [
        {
          'name': 'Deutscher Marker',
          'image': 'Icon_invalid_localized_variant',
          'needsSetup': false,
        },
      ],
      'tipsAndTricks': <String>[],
      'bluffs': <String>[],
    };

    final character = CharacterService.mergeLocalizedCatalog(
      [english],
      [german],
    ).single;

    expect(character.name, 'Deutsche Rolle');
    expect(character.descriptionShort, 'Deutsche Fähigkeit');
    expect(character.descriptionLong, 'English long description');
    expect(character.howToRun, 'English storyteller instructions');
    expect(character.help, isEmpty);
    expect(character.tipsAndTricks, isEmpty);
    expect(character.bluffs, isEmpty);
    expect(character.image, 'Icon_example');
    expect(character.fraction.name, 'townsfolk');
    expect(character.gameset.single.name, 'trouble_brewing');
    expect(character.wakeUpEveryNight, isFalse);
    expect(character.nightStateNumbersFirstNight, isEmpty);
    expect(character.tokens.single.name, 'Deutscher Marker');
    expect(character.tokens.single.image, 'Icon_example');
    expect(character.tokens.single.needsSetup, isTrue);
  });

  test('language changes leave game instances and positions untouched',
      () async {
    final service = CharacterService();
    await service.loadAllCharactersFromJson(const Locale('en'));
    service.addCharacter(roleById(service.allCharacters, 'imp'));
    service.setCharacterPosition(0, const Offset(12, 34));
    final gameBefore =
        service.gameCharacters.map((item) => item.toJson()).toList();
    final positionsBefore = Map<int, Offset>.from(service.characterPositions);

    await service.loadAllCharactersFromJson(const Locale('de'));

    expect(service.gameCharacters.map((item) => item.toJson()), gameBefore);
    expect(service.characterPositions, positionsBefore);
    expect(service.allCharacters, hasLength(181));
  });

  test(
      'standard, Experimental and custom scripts resolve identically in DE and EN',
      () async {
    final englishRaw = await loadCatalog('en');
    final germanRaw = await loadCatalog('de');
    final english = englishRaw
        .cast<Map<String, dynamic>>()
        .map(Character.fromJson)
        .toList();
    final german =
        CharacterService.mergeLocalizedCatalog(englishRaw, germanRaw);
    final scripts = ScriptService();
    await scripts.ready;
    final custom = BotcScript(
      id: 'custom:language-fallback',
      name: 'Language fallback',
      roleIds: const ['bigwig', 'imp', 'zenomancer'],
    );
    await scripts.upsertScript(custom);

    for (final scriptId in [
      ScriptService.troubleBrewingId,
      ScriptService.sectsAndVioletsId,
      ScriptService.badMoonRisingId,
      ScriptService.experimentalId,
      custom.id,
    ]) {
      await scripts.selectScript(scriptId, gameIsRunning: false);
      expect(
        scripts.resolveCharacters(german).map((role) => role.roleId),
        orderedEquals(
          scripts.resolveCharacters(english).map((role) => role.roleId),
        ),
        reason: scriptId,
      );
      expect(scripts.unresolvedRoleIds(german), isEmpty, reason: scriptId);
    }
  });
}
