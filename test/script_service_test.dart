import 'dart:convert';
import 'dart:io';

import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('script model preserves ordered official role IDs', () {
    final script = BotcScript(
      id: 'custom:one-in-one-out',
      name: 'One in one out',
      author: 'Baron von Klutz',
      roleIds: const ['steward', 'knight', 'imp'],
    );

    final restored = BotcScript.fromJson(script.toJson());

    expect(restored.id, script.id);
    expect(restored.name, script.name);
    expect(restored.author, script.author);
    expect(restored.roleIds, orderedEquals(['steward', 'knight', 'imp']));
  });

  test('complexities serialize optional values and reject invalid steps', () {
    final script = BotcScript(
      id: 'custom:ratings',
      name: 'Ratings',
      roleIds: const ['imp'],
      storytellerComplexity: 0,
      playerComplexity: 3.5,
    );
    final restored = BotcScript.fromJson(script.toJson());

    expect(restored.storytellerComplexity, 0);
    expect(restored.playerComplexity, 3.5);
    expect(
      BotcScript.fromJson({
        'id': 'custom:legacy',
        'name': 'Legacy',
        'roleIds': ['imp'],
      }).storytellerComplexity,
      isNull,
    );
    expect(
      () => BotcScript(
        id: 'custom:invalid',
        name: 'Invalid',
        roleIds: const ['imp'],
        storytellerComplexity: 2.25,
      ),
      throwsArgumentError,
    );
  });

  test('custom scripts and selection persist locally', () async {
    final service = ScriptService();
    await service.ready;
    final custom = BotcScript(
      id: 'custom:test',
      name: 'Test Script',
      author: 'Tester',
      roleIds: const ['imp', 'poisoner'],
    );

    await service.upsertScript(custom);
    expect(await service.selectScript(custom.id, gameIsRunning: false), isTrue);

    final restored = ScriptService();
    await restored.ready;
    expect(restored.selectedScriptId, custom.id);
    expect(restored.selectedScript.roleIds, orderedEquals(custom.roleIds));
  });

  test('custom script complexities persist and can be removed', () async {
    final service = ScriptService();
    await service.ready;
    final custom = BotcScript(
      id: 'custom:complexities',
      name: 'Complexities',
      roleIds: const ['imp'],
    );
    await service.upsertScript(custom);
    await service.setComplexities(
      custom.id,
      storytellerComplexity: 0,
      playerComplexity: 4.5,
    );

    final restored = ScriptService();
    await restored.ready;
    expect(restored.storytellerComplexityFor(custom.id), 0);
    expect(restored.playerComplexityFor(custom.id), 4.5);

    await restored.setComplexities(
      custom.id,
      storytellerComplexity: null,
      playerComplexity: null,
    );
    expect(restored.storytellerComplexityFor(custom.id), isNull);
    expect(restored.playerComplexityFor(custom.id), isNull);
  });

  test('standard defaults allow local overrides and reset without game changes',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'night_count': 2});
    final scripts = ScriptService();
    await scripts.ready;
    final gameState = GameStateService(scriptService: scripts);
    await gameState.init();

    expect(
      scripts.storytellerComplexityFor(ScriptService.troubleBrewingId),
      1.5,
    );
    expect(scripts.playerComplexityFor(ScriptService.badMoonRisingId), 3.5);
    expect(
        scripts.storytellerComplexityFor(ScriptService.experimentalId), isNull);

    await scripts.setComplexities(
      ScriptService.troubleBrewingId,
      storytellerComplexity: 5,
      playerComplexity: null,
    );
    expect(
      scripts.storytellerComplexityFor(ScriptService.troubleBrewingId),
      5,
    );
    expect(scripts.playerComplexityFor(ScriptService.troubleBrewingId), isNull);
    expect(gameState.nightCount, 2);

    final restored = ScriptService();
    await restored.ready;
    expect(
      restored.storytellerComplexityFor(ScriptService.troubleBrewingId),
      5,
    );
    await restored.resetComplexities(ScriptService.troubleBrewingId);
    expect(
      restored.storytellerComplexityFor(ScriptService.troubleBrewingId),
      1.5,
    );
    expect(restored.playerComplexityFor(ScriptService.troubleBrewingId), 1.5);
  });

  test('legacy gameset selection migrates without changing its key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gameset': Gameset.sects_and_violets.toString(),
      'character_list': '[]',
    });

    final scripts = ScriptService();
    await scripts.ready;
    final gameState = GameStateService(scriptService: scripts);
    await gameState.init();

    expect(scripts.selectedScriptId, ScriptService.sectsAndVioletsId);
    expect(gameState.gameset, Gameset.sects_and_violets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('gameset'), Gameset.sects_and_violets.toString());
  });

  test('all standard scripts resolve unchanged and Experimental stays dynamic',
      () async {
    final catalog = await loadEnglishCatalog();
    final service = ScriptService();
    await service.ready;

    for (final scriptId in [
      ScriptService.troubleBrewingId,
      ScriptService.sectsAndVioletsId,
      ScriptService.badMoonRisingId,
    ]) {
      await service.selectScript(scriptId, gameIsRunning: false);
      expect(
        service.resolveCharacters(catalog).map((role) => role.roleId),
        orderedEquals(service.selectedScript.roleIds),
        reason: scriptId,
      );
      expect(service.unresolvedRoleIds(catalog), isEmpty, reason: scriptId);
    }

    await service.selectScript(
      ScriptService.experimentalId,
      gameIsRunning: false,
    );
    final expectedExperimental = catalog
        .where((role) => role.gameset.contains(Gameset.experimental))
        .map((role) => role.roleId);
    expect(
      service.resolveCharacters(catalog).map((role) => role.roleId),
      orderedEquals(expectedExperimental),
    );
  });

  test('missing localized roles do not invalidate a custom script', () async {
    final catalog = await loadEnglishCatalog();
    final service = ScriptService();
    await service.ready;
    final custom = BotcScript(
      id: 'custom:fallback-ready',
      name: 'Fallback Ready',
      roleIds: const ['imp', 'role-not-in-current-locale', 'poisoner'],
    );
    await service.upsertScript(custom);
    await service.selectScript(custom.id, gameIsRunning: false);

    expect(
      service.resolveCharacters(catalog).map((role) => role.roleId),
      orderedEquals(['imp', 'poisoner']),
    );
    expect(
      service.unresolvedRoleIds(catalog),
      orderedEquals(['role-not-in-current-locale']),
    );
  });

  test('running games reject script changes without losing selection',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'night_count': 2,
    });
    final scripts = ScriptService();
    await scripts.ready;
    final gameState = GameStateService(scriptService: scripts);
    await gameState.init();

    final changed = await gameState.selectScript(
      ScriptService.badMoonRisingId,
      const [],
    );

    expect(changed, isFalse);
    expect(scripts.selectedScriptId, ScriptService.troubleBrewingId);
    expect(gameState.nightCount, 2);
  });

  test('custom scripts can be deleted only outside a running game', () async {
    final scripts = ScriptService();
    await scripts.ready;
    final custom = BotcScript(
      id: 'custom:delete-me',
      name: 'Delete me',
      roleIds: const ['imp'],
    );
    await scripts.upsertScript(custom);
    await scripts.selectScript(custom.id, gameIsRunning: false);

    expect(
      await scripts.removeScript(custom.id, gameIsRunning: true),
      isFalse,
    );
    expect(scripts.selectedScriptId, custom.id);
    expect(scripts.customScripts, contains(custom));

    expect(
      await scripts.removeScript(custom.id, gameIsRunning: false),
      isTrue,
    );
    expect(scripts.customScripts, isEmpty);
    expect(scripts.selectedScriptId, ScriptService.troubleBrewingId);

    final restored = ScriptService();
    await restored.ready;
    expect(restored.customScripts, isEmpty);
  });
}
