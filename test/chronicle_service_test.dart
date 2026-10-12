import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> catalog;

  setUpAll(() async {
    catalog = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Character catalogRole(String roleId, {String? id, String? playerName}) {
    final json = catalog.singleWhere((role) => role['roleId'] == roleId);
    return Character.fromJson({
      ...json,
      'id': id ?? '$roleId-instance',
      'playerName': playerName ?? roleId,
    });
  }

  Character player(String id, String name) => Character(
        id: id,
        roleId: id,
        name: id,
        playerName: name,
        descriptionShort: '',
        descriptionLong: '',
        howToRun: '',
        image: 'Icon_$id',
        fraction: Fraction.townsfolk,
        tokens: const [],
        wakeUpEveryNight: false,
        wakeUpAtFirstNight: false,
        gameset: const [Gameset.experimental],
        nightStateNumbersFirstNight: const [],
        nightStateNumbersOtherNights: const [],
        tipsAndTricks: const [],
        bluffs: const [],
      );

  Future<GameStateService> gameState(ChronicleService chronicle) async {
    final scripts = ScriptService();
    final order = NightOrderService();
    await Future.wait([scripts.ready, order.ready, chronicle.ready]);
    final state = GameStateService(
      scriptService: scripts,
      nightOrderService: order,
      chronicleService: chronicle,
    );
    await state.ready;
    return state;
  }

  test('catalog schemas expose Chef, Empath and Fortune Teller definitions',
      () {
    final chef = catalogRole('chef').chronicle!;
    expect(chef.firstNight.single.type, ChronicleInputType.number);
    expect(chef.firstNight.single.min, 0);
    expect(chef.firstNight.single.max, isNull);

    final empath = catalogRole('empath').chronicle!;
    expect(empath.firstNight.single.max, 2);
    expect(empath.otherNights.single.max, 2);

    final fortune = catalogRole('fortuneteller').chronicle!;
    expect(fortune.otherNights.single.type, ChronicleInputType.form);
    expect(
      fortune.otherNights.single.fields.map((field) => field.type),
      [ChronicleInputType.players, ChronicleInputType.yesNo],
    );
  });

  test('records, corrects and restores optional night information', () async {
    final service = ChronicleService();
    await service.ready;
    final chef = catalogRole('chef', playerName: 'Alex');
    await service.startNewGame([chef]);
    await service.recordPhase(ChroniclePhase.night, 1);
    await service.recordNightVisit(chef, 1);

    final pending = service.activeChronicle!.events.singleWhere(
      (event) => event.type == ChronicleEventType.nightInformation,
    );
    expect(pending.hasInformation, isFalse);
    final entryId = await service.saveInformationEntry(
      eventId: pending.id,
      values: const {'chefCount': 2},
    );
    await service.saveInformationEntry(
      eventId: pending.id,
      entryId: entryId,
      values: const {'chefCount': 1},
    );

    final restored = ChronicleService();
    await restored.ready;
    final saved = restored.activeChronicle!.events.singleWhere(
      (event) => event.id == pending.id,
    );
    expect(saved.hasInformation, isTrue);
    expect(saved.informationEntries.single['values']['chefCount'], 1);
    expect(saved.character?.playerName, 'Alex');
  });

  test('stores players and yes/no without changing game state', () async {
    final service = ChronicleService();
    await service.ready;
    final fortuneTeller = catalogRole('fortuneteller', playerName: 'Faye');
    final first = player('one', 'One');
    final second = player('two', 'Two');
    await service.startNewGame([fortuneTeller, first, second]);
    await service.recordNightVisit(fortuneTeller, 1);
    final pending = service.activeChronicle!.events.singleWhere(
      (event) => event.type == ChronicleEventType.nightInformation,
    );

    await service.saveInformationEntry(
      eventId: pending.id,
      values: {
        'chosenPlayers': [
          ChronicleCharacterSnapshot.fromCharacter(first).toJson(),
          ChronicleCharacterSnapshot.fromCharacter(second).toJson(),
        ],
        'answer': true,
      },
      targets: [first, second]
          .map(ChronicleCharacterSnapshot.fromCharacter)
          .toList(),
    );

    final saved = service.activeChronicle!.events.singleWhere(
      (event) => event.id == pending.id,
    );
    expect(saved.informationEntries.single['values']['answer'], isTrue);
    expect(saved.targets.map((target) => target.playerName), ['One', 'Two']);
  });

  test('backward night navigation does not duplicate phase or input entries',
      () async {
    final chronicle = ChronicleService();
    final state = await gameState(chronicle);
    final chef = catalogRole('chef');
    await state.startNewGame([chef]);

    for (var i = 0; i < 20 && !state.isDay(); i++) {
      await state.nextNightState([chef]);
    }
    expect(state.isDay(), isTrue);
    final countBefore = chronicle.activeChronicle!.events.length;
    await state.previousNightState([chef]);
    await state.nextNightState([chef]);

    expect(chronicle.activeChronicle!.events.length, countBefore);
    expect(
      chronicle.activeChronicle!.events
          .where((event) => event.type == ChronicleEventType.nightInformation),
      hasLength(1),
    );
    expect(
      chronicle.activeChronicle!.events.where(
        (event) =>
            event.type == ChronicleEventType.phaseStarted &&
            event.phase == ChroniclePhase.night &&
            event.round == 1,
      ),
      hasLength(1),
    );
    expect(
      chronicle.activeChronicle!.events.where(
        (event) =>
            event.type == ChronicleEventType.phaseStarted &&
            event.phase == ChroniclePhase.day &&
            event.round == 1,
      ),
      hasLength(1),
    );
  });

  test('manual QuickFlow selections are recorded through GameStateService',
      () async {
    final chronicle = ChronicleService();
    final state = await gameState(chronicle);
    final owner = catalogRole('cerenovus', id: 'owner', playerName: 'Owner');
    final selected = player('selected', 'Selected');
    const step = QuickFlowStep(
      id: 'role-choice',
      type: QuickFlowStepType.reminderCharacterToken,
      selection: QuickFlowCharacterSelection(type: 'manual'),
      allowedFractions: ['townsfolk'],
      allowManualOverride: true,
    );
    final entry = QuickFlowEntry(
      owner: owner,
      phase: QuickFlowPhase.firstNight,
      step: step,
    );
    await state.startNewGame([owner, selected]);

    expect(await state.setQuickFlowSelectedCharacter(entry, selected), isTrue);
    expect(
      chronicle.activeChronicle!.events.where(
        (event) =>
            event.type == ChronicleEventType.quickFlowCharacterSelected &&
            event.details['stepId'] == 'role-choice' &&
            event.targets.single.characterId == selected.id,
      ),
      hasLength(1),
    );
  });

  test('character changes are recorded through CharacterService', () async {
    final chronicle = ChronicleService();
    await chronicle.ready;
    final oldCharacter = player('old-role', 'Player');
    final newCharacter = player('new-role', 'Unused');
    await chronicle.startNewGame([oldCharacter]);
    final characters = CharacterService(chronicleService: chronicle);
    await characters.init();
    characters.addCharacter(oldCharacter);
    final current = characters.gameCharacters.single;

    characters.changeCharacter(current, newCharacter);

    final event = chronicle.activeChronicle!.events.singleWhere(
      (event) => event.type == ChronicleEventType.characterChanged,
    );
    expect(event.character?.roleId, oldCharacter.roleId);
    expect(event.targets.single.roleId, newCharacter.roleId);
    expect(event.targets.single.playerName, 'Player');
  });

  test('marker move is recorded once and repeated same target is a no-op',
      () async {
    final chronicle = ChronicleService();
    final state = await gameState(chronicle);
    final owner = Character(
      id: 'owner',
      roleId: 'owner',
      name: 'Owner',
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_owner',
      fraction: Fraction.townsfolk,
      tokens: [Token(name: 'Marked', image: 'Icon_owner', quickId: 'marked')],
      wakeUpEveryNight: false,
      wakeUpAtFirstNight: false,
      gameset: const [Gameset.experimental],
      nightStateNumbersFirstNight: const [],
      nightStateNumbersOtherNights: const [],
      tipsAndTricks: const [],
      bluffs: const [],
    );
    final first = player('first', 'First');
    final second = player('second', 'Second');
    final characters = [owner, first, second];
    await state.startNewGame(characters);
    state.initUnusedGameTokens(characters);
    final token = owner.tokens.single;

    await state.addTokenToCharacter(characters, first, token);
    await state.addTokenToCharacter(characters, second, token);
    await state.addTokenToCharacter(characters, second, token);

    final events = chronicle.activeChronicle!.events
        .where((event) => event.type == ChronicleEventType.reminderAssigned)
        .toList();
    expect(events, hasLength(2));
    expect(events.last.character?.characterId, second.id);
    expect(events.last.targets.single.characterId, first.id);
  });

  test('life changes remain distinct from reminders and game end archives',
      () async {
    final chronicle = ChronicleService();
    final state = await gameState(chronicle);
    final character = player('farmer', 'Fran');
    await state.startNewGame([character]);
    await state.toggleCharacterAlive(character);
    await state.endGame();

    expect(chronicle.activeChronicle, isNull);
    expect(chronicle.lastChronicle, isNotNull);
    final events = chronicle.lastChronicle!.events;
    expect(
      events.where((event) =>
          event.type == ChronicleEventType.lifeStatusChanged &&
          event.details['alive'] == false),
      hasLength(1),
    );
    expect(
      events
          .where((event) => event.type == ChronicleEventType.reminderAssigned),
      isEmpty,
    );
  });

  test('factory reset clears active and archived chronicle data', () async {
    final service = ChronicleService();
    await service.ready;
    await service.startNewGame([player('one', 'One')]);
    await service.archiveCurrent();
    await service.factoryReset();

    final restored = ChronicleService();
    await restored.ready;
    expect(restored.activeChronicle, isNull);
    expect(restored.lastChronicle, isNull);
  });

  test('starting a new game archives the old log and creates a new game id',
      () async {
    final service = ChronicleService();
    await service.ready;
    await service.startNewGame([player('one', 'One')]);
    final firstGameId = service.activeChronicle!.gameId;

    await service.startNewGame([player('two', 'Two')]);

    expect(service.lastChronicle?.gameId, firstGameId);
    expect(service.lastChronicle?.endedAt, isNotNull);
    expect(service.activeChronicle?.gameId, isNot(firstGameId));
    final startedPlayers = service.activeChronicle!.events.first.targets;
    expect(startedPlayers.single.playerName, 'Two');
  });
}
