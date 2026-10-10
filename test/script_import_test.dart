import 'dart:convert';
import 'dart:io';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/script_import.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const oneInOneOutRoleIds = [
  'steward',
  'knight',
  'highpriestess',
  'villageidiot',
  'snakecharmer',
  'fortuneteller',
  'oracle',
  'monk',
  'amnesiac',
  'fisherman',
  'seamstress',
  'farmer',
  'cannibal',
  'ogre',
  'goon',
  'recluse',
  'drunk',
  'poisoner',
  'harpy',
  'spy',
  'mezepheles',
  'kazali',
  'imp',
  'ojo',
  'fanggu',
  'spiritofivory',
];

String officialOneInOneOutJson() {
  return jsonEncode([
    {
      'id': '_meta',
      'author': 'Baron von Klutz',
      'name': 'One in one out',
      'bloodstarImageCorrection': 'on',
      'autosort': false,
      'type': 'full',
    },
    ...oneInOneOutRoleIds.map(
      (id) => {'id': id, 'ghost': false, 'pinned': false},
    ),
  ]);
}

Future<List<Character>> loadEnglishCatalog() async {
  final raw = await File('assets/characters/en.json').readAsString();
  return (jsonDecode(raw) as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(Character.fromJson)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('imports the 26 official One in one out roles from object entries',
      () async {
    final characters = CharacterService();
    await characters.loadAllCharactersFromJson(const Locale('de'));
    final scripts = ScriptService();
    await scripts.ready;

    final draft = await scripts.inspectImportJson(
      officialOneInOneOutJson(),
      characters,
    );

    expect(draft.name, 'One in one out');
    expect(draft.author, 'Baron von Klutz');
    expect(draft.roles, hasLength(26));
    expect(draft.resolvedRoleIds, orderedEquals(oneInOneOutRoleIds));
    expect(draft.issues, isEmpty);
    expect(draft.canBeConfirmed, isTrue);

    final saved = await scripts.confirmImport(
      draft,
      scriptId: 'custom:one-in-one-out',
    );
    await scripts.selectScript(saved.id, gameIsRunning: false);
    expect(
      scripts
          .resolveCharacters(characters.allCharacters)
          .map((role) => role.roleId),
      orderedEquals(oneInOneOutRoleIds),
    );

    await scripts.confirmImport(draft, scriptId: 'custom:one-in-one-out-copy');
    final reloaded = ScriptService();
    await reloaded.ready;
    expect(
      reloaded.customScripts.where((script) => script.name == 'One in one out'),
      hasLength(2),
    );
  });

  test(
      'keeps unknown and homebrew entries unresolved until mapped and confirmed',
      () async {
    final characters = CharacterService();
    final scripts = ScriptService();
    await scripts.ready;
    final source = jsonEncode([
      {'id': '_meta', 'name': 'Mapping test'},
      'imp',
      'not-in-the-catalog',
      {
        'id': 'custom-role',
        'name': 'A homebrew role',
        'ability': 'Unsupported'
      },
    ]);

    final draft = await scripts.inspectImportJson(source, characters);
    expect(draft.canBeConfirmed, isFalse);
    expect(
      draft.issues.map((issue) => issue.type),
      containsAll([
        ScriptImportIssueType.unknownRoleId,
        ScriptImportIssueType.unsupportedHomebrewDefinition,
      ]),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(scripts.customScripts, isEmpty);
    expect(prefs.getStringList('custom_scripts'), isNull);

    final afterFirstMapping = await scripts.mapImportedRole(
      draft,
      roleIndex: 1,
      canonicalRoleId: 'poisoner',
      characterService: characters,
    );
    final resolved = await scripts.mapImportedRole(
      afterFirstMapping,
      roleIndex: 2,
      canonicalRoleId: 'fanggu',
      characterService: characters,
    );
    expect(
        resolved.resolvedRoleIds, orderedEquals(['imp', 'poisoner', 'fanggu']));
    expect(scripts.customScripts, isEmpty);
    expect(prefs.getStringList('custom_scripts'), isNull);

    await scripts.confirmImport(resolved, scriptId: 'custom:mapping-test');
    expect(scripts.customScripts.single.roleIds,
        orderedEquals(['imp', 'poisoner', 'fanggu']));
  });

  test('persists import complexities independently, including zero', () async {
    final characters = CharacterService();
    final scripts = ScriptService();
    await scripts.ready;
    final draft = await scripts.inspectImportJson(
      jsonEncode([
        {'id': '_meta', 'name': 'Rated import'},
        'imp',
      ]),
      characters,
    );

    final bothRated = await scripts.confirmImport(
      draft,
      scriptId: 'custom:both-rated',
      storytellerComplexity: 0,
      playerComplexity: 4.5,
    );
    final unrated = await scripts.confirmImport(
      draft,
      scriptId: 'custom:unrated',
    );
    final playerOnly = await scripts.confirmImport(
      draft,
      scriptId: 'custom:player-only',
      playerComplexity: 2.5,
    );

    expect(bothRated.storytellerComplexity, 0);
    expect(bothRated.playerComplexity, 4.5);
    expect(unrated.storytellerComplexity, isNull);
    expect(unrated.playerComplexity, isNull);
    expect(playerOnly.storytellerComplexity, isNull);
    expect(playerOnly.playerComplexity, 2.5);

    final reloaded = ScriptService();
    await reloaded.ready;
    final reloadedBothRated = reloaded.customScripts
        .singleWhere((script) => script.id == 'custom:both-rated');
    final reloadedUnrated = reloaded.customScripts
        .singleWhere((script) => script.id == 'custom:unrated');
    final reloadedPlayerOnly = reloaded.customScripts
        .singleWhere((script) => script.id == 'custom:player-only');
    expect(reloadedBothRated.storytellerComplexity, 0);
    expect(reloadedBothRated.playerComplexity, 4.5);
    expect(reloadedUnrated.playerComplexity, isNull);
    expect(reloadedPlayerOnly.playerComplexity, 2.5);
  });

  test('does not persist an inspected import that is abandoned', () async {
    final characters = CharacterService();
    final scripts = ScriptService();
    await scripts.ready;

    final draft = await scripts.inspectImportJson(
      jsonEncode([
        {'id': '_meta', 'name': 'Abandoned import'},
        'imp',
      ]),
      characters,
    );

    expect(draft.canBeConfirmed, isTrue);
    expect(scripts.customScripts, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('custom_scripts'), isNull);
  });

  test(
      'returns structured validation for malformed, duplicate and ambiguous IDs',
      () async {
    final scripts = ScriptService();
    await scripts.ready;
    final catalog = await loadEnglishCatalog();

    final invalidJson = scripts.inspectImportJsonAgainstCatalog('{', catalog);
    expect(invalidJson.issues.single.type, ScriptImportIssueType.invalidJson);

    final duplicate = scripts.inspectImportJsonAgainstCatalog(
      jsonEncode([
        {'id': '_meta', 'name': 'Duplicate'},
        'imp',
        'imp',
      ]),
      catalog,
    );
    expect(
      duplicate.issues.map((issue) => issue.type),
      contains(ScriptImportIssueType.duplicateRoleId),
    );
    expect(duplicate.canBeConfirmed, isFalse);
    expect(() => scripts.confirmImport(duplicate), throwsStateError);

    final imp = catalog.singleWhere((character) => character.roleId == 'imp');
    final ambiguous = scripts.inspectImportJsonAgainstCatalog(
      jsonEncode([
        {'id': '_meta', 'name': 'Ambiguous'},
        'imp',
      ]),
      [imp, imp.copyWith(id: 'another-imp-instance')],
    );
    expect(
      ambiguous.unresolvedRoles.single.issue!.type,
      ScriptImportIssueType.ambiguousRoleId,
    );
  });
}
