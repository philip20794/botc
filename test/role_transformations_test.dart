import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(CharacterService, GameStateService)> create() async {
    final chronicles = ChronicleService();
    final scripts = ScriptService();
    final order = NightOrderService();
    final characters = CharacterService(chronicleService: chronicles);
    await Future.wait([chronicles.ready, scripts.ready, order.ready,
      characters.init()]);
    await characters.loadAllCharactersFromJson(const Locale('en'));
    final game = GameStateService(scriptService: scripts,
        nightOrderService: order, chronicleService: chronicles);
    await game.ready;
    return (characters, game);
  }

  void setup(CharacterService chars, String roleId) {
    chars.addCharacter(chars.allCharacters.singleWhere(
        (role) => role.roleId == roleId));
  }

  Future<void> advanceTo(
      GameStateService game, CharacterService characters,
      bool Function() done) async {
    for (var i = 0; i < 150 && !done(); i++) {
      await game.nextNightState(characters.gameCharacters);
    }
    expect(done(), isTrue);
  }

  test('Riot has one initial Demon, Minions stay until night 3', () async {
    final (characters, game) = await create();
    setup(characters, 'riot');
    setup(characters, 'poisoner');
    setup(characters, 'scarletwoman');
    final initial = characters.gameCharacters.toList();
    expect(initial.where((x) => x.roleId == 'riot').length, 1);
    expect(initial.where((x) => x.fraction == Fraction.minion).length, 2);

    await game.startNewGame(characters.gameCharacters);
    await advanceTo(game, characters, () =>
      game.nightCount == 2 && game.isCharacterAwake(
          characters.gameCharacters.firstWhere((x) => x.roleId == 'riot')));
    expect(game.quickFlowEntries(characters.gameCharacters), isEmpty,
        reason: 'Riot transformation must not appear on night 2');

    await advanceTo(game, characters, () =>
      game.nightCount == 3 && game.isCharacterAwake(
          characters.gameCharacters.firstWhere((x) => x.roleId == 'riot')));
    final entries = game.quickFlowEntries(characters.gameCharacters);
    expect(entries.length, 1);
    expect(entries.single.step.type, QuickFlowStepType.roleChange);
    final firstMinion = characters.gameCharacters.firstWhere(
        (character) => character.fraction == Fraction.minion);
    expect(await game.applyQuickFlowRoleChange(
        entries.single, firstMinion, characters), isTrue);
    expect(characters.gameCharacters
        .where((x) => x.roleId == 'riot').length, 2);
    expect(game.isQuickFlowEntryCompleted(
        entries.single, characters.gameCharacters), isFalse);

    final secondMinion = characters.gameCharacters.firstWhere(
        (character) => character.fraction == Fraction.minion);
    expect(await game.applyQuickFlowRoleChange(
        entries.single, secondMinion, characters), isTrue);
    expect(characters.gameCharacters
        .where((x) => x.roleId == 'riot').length, 3);
    expect(characters.gameCharacters
        .where((x) => x.fraction == Fraction.minion), isEmpty);
    expect(game.isQuickFlowEntryCompleted(
        entries.single, characters.gameCharacters), isTrue);
    final restored = ChronicleService();
    await restored.ready;
    final changes = restored.activeChronicle!.events
        .where((event) => event.type == ChronicleEventType.characterChanged)
        .toList();
    expect(changes.length, 2);
    expect(changes.every((event) =>
        event.character?.roleId != 'riot' &&
        event.targets.single.roleId == 'riot'), isTrue);
  });

  test('Farmer is woken ONLY on night of death and converts chosen good',
      () async {
    final (characters, game) = await create();
    setup(characters, 'farmer');
    setup(characters, 'chef');
    final farmer = characters.gameCharacters
        .firstWhere((x) => x.roleId == 'farmer');
    await game.startNewGame(characters.gameCharacters);
    await advanceTo(game, characters, () =>
        game.nightCount == 2 && game.currentNightStepId == 'phase:dusk');
    expect(game.currentNightStepId, 'phase:dusk');
    await game.toggleCharacterAlive(farmer);
    expect(game.wasFarmerKilledTonight(farmer), isTrue);
    await advanceTo(game, characters, () => game.isCharacterAwake(farmer));
    final entries = game.quickFlowEntries(characters.gameCharacters);
    final mark = entries.firstWhere((e) => e.step.id == 'newFarmerPlayer');
    final show = entries.firstWhere((e) => e.step.id == 'showNewFarmer');
    final change = entries.firstWhere((e) => e.step.id == 'convertToFarmer');
    final chef = characters.gameCharacters
        .firstWhere((x) => x.roleId == 'chef');
    expect(await game.applyQuickFlowRoleChange(change, chef, characters),
        isFalse, reason: 'Must finish YOU ARE before changing character');
    final selected = await game.assignActiveQuickFlowReminder(
        characters.gameCharacters, chef);
    expect(selected.success, isTrue);
    expect(game.quickFlowTarget(mark, characters.gameCharacters)?.id,
        chef.id);
    final tokenChoice = entries.firstWhere((e) => e.step.id == 'farmerCharacter');
    await game.setQuickFlowSelectedCharacter(
        tokenChoice, characters.allCharacters
            .firstWhere((x) => x.roleId == 'farmer'));
    await game.completeQuickFlowEntry(tokenChoice, characters.gameCharacters);
    expect(game.isQuickFlowInfoReady(
        show, characters.gameCharacters, characters.allCharacters), isTrue);
    await game.confirmQuickFlowInfo(show);
    await game.completeQuickFlowEntry(show, characters.gameCharacters);
    expect(await game.applyQuickFlowRoleChange(
        change, chef, characters), isTrue);
    expect(characters.gameCharacters.where((x) => x.roleId == 'farmer')
        .length, 2);
    expect(game.isCharacterAlive(farmer), isFalse);
    final newFarmer = characters.gameCharacters.firstWhere(
        (x) => x.roleId == 'farmer' && x.id != farmer.id);
    expect(newFarmer.playerName, chef.playerName);
    expect(game.isCharacterAlive(newFarmer), isTrue);
    final restored = ChronicleService();
    await restored.ready;
    expect(restored.activeChronicle!.events.any((event) =>
        event.type == ChronicleEventType.characterChanged &&
        event.character?.roleId == 'chef' &&
        event.targets.single.roleId == 'farmer'), isTrue);
  });
}
