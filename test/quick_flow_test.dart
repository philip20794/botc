import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _roleJson(
  String roleId, {
  String? id,
  String? playerName,
  Fraction fraction = Fraction.townsfolk,
  List<Map<String, dynamic>> tokens = const [],
  Map<String, dynamic>? quickFlow,
}) =>
    {
      'id': id ?? '$roleId-instance',
      'roleId': roleId,
      'name': roleId,
      'descriptionShort': '',
      'descriptionLong': '',
      'howToRun': '',
      'image': 'Icon_$roleId',
      'fraction': fraction.name,
      'gameset': ['experimental'],
      'tokens': tokens,
      'wakeUpEveryNight': false,
      'wakeUpAtFirstNight': false,
      'nightStateNumbersFirstNight': <double>[],
      'nightStateNumbersOtherNights': <double>[],
      'tipsAndTricks': <String>[],
      'bluffs': <String>[],
      'playerName': playerName ?? roleId,
      if (quickFlow != null) 'quickFlow': quickFlow,
    };

Character _role(
  String roleId, {
  String? id,
  String? playerName,
  Fraction fraction = Fraction.townsfolk,
  List<Map<String, dynamic>> tokens = const [],
  Map<String, dynamic>? quickFlow,
}) =>
    Character.fromJson(_roleJson(
      roleId,
      id: id,
      playerName: playerName,
      fraction: fraction,
      tokens: tokens,
      quickFlow: quickFlow,
    ));

Map<String, dynamic> _token(String name, String quickId,
        {bool unlimited = false}) =>
    {
      'name': name,
      'image': 'Icon_${name.toLowerCase().replaceAll(' ', '')}',
      'quickId': quickId,
      if (unlimited) 'unlimited': true,
    };

Map<String, dynamic> _reminder(
  String id,
  String tokenId, {
  String operation = 'move',
  List<String> distinctFrom = const [],
  Map<String, dynamic>? allowedTargets,
}) =>
    {
      'id': id,
      'type': 'reminder',
      'tokenId': tokenId,
      'operation': operation,
      if (distinctFrom.isNotEmpty) 'distinctFrom': distinctFrom,
      if (allowedTargets != null) 'allowedTargets': allowedTargets,
    };

QuickFlowEntry _entry(
  Character owner,
  QuickFlowPhase phase,
  String id,
) =>
    QuickFlowEntry(
      owner: owner,
      phase: phase,
      step:
          owner.quickFlow.stepsFor(phase).singleWhere((step) => step.id == id),
    );

Future<GameStateService> _state(
    {Map<String, Object> initial = const {}}) async {
  SharedPreferences.setMockInitialValues(initial);
  final state = GameStateService();
  await state.ready;
  return state;
}

Future<GameStateService> _nightState(
  Character owner,
  List<Character> characters, {
  int night = 2,
}) async {
  final state = await _state(initial: {
    'night_count': night,
    'night_step_id': 'role:${owner.roleId}:${owner.id}',
  });
  state.initUnusedGameTokens(characters);
  await state.synchronizeNightStep(characters);
  expect(state.currentNightStepId, 'role:${owner.roleId}:${owner.id}');
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parser accepts optional quick flow fields and ignores invalid steps',
      () {
    final character = Character.fromJson({
      ..._roleJson(
        'parser',
        tokens: [_token('Mad', 'mad')],
        quickFlow: {
          'setup': [
            _reminder('madPlayer', 'mad', operation: 'setOnce'),
            {'id': 'future', 'type': 'unknown'},
            {'type': 'reminder', 'tokenId': 'mad', 'operation': 'move'},
          ],
        },
      ),
    });

    expect(character.tokens.single.quickId, 'mad');
    expect(character.quickFlow.setup, hasLength(1));
    expect(character.toJson()['quickFlow'], isNotNull);
  });

  test('broken QuickFlow references remain safely blocked', () async {
    final owner = _role(
      'broken',
      tokens: [_token('Mark', 'mark')],
      quickFlow: {
        'setup': [
          _reminder('markPlayer', 'mark', distinctFrom: ['missingStep']),
        ],
      },
    );
    final target = _role('target', id: 'target');
    final characters = [owner, target];
    final state = await _state();
    state.initUnusedGameTokens(characters);

    final result =
        await state.assignActiveQuickFlowReminder(characters, target);

    expect(result.success, isFalse);
    expect(result.failure, QuickFlowAssignmentFailure.unsupported);
    expect(state.tokensOfCharacter(target), isEmpty);
  });

  test('Monk keeps the same target and moves the existing reminder', () async {
    final monk = _role(
      'monk',
      tokens: [_token('Save', 'save')],
      quickFlow: {
        'otherNights': [_reminder('protectedPlayer', 'save')],
      },
    );
    final a = _role('washerwoman', id: 'a', playerName: 'A');
    final b = _role('investigator', id: 'b', playerName: 'B');
    final characters = [monk, a, b];
    final state = await _nightState(monk, characters);

    expect((await state.assignActiveQuickFlowReminder(characters, a)).success,
        isTrue);
    await state.activateQuickFlowEntry(
        _entry(monk, QuickFlowPhase.otherNights, 'protectedPlayer'),
        characters);
    expect((await state.assignActiveQuickFlowReminder(characters, a)).success,
        isTrue);
    expect(state.tokensOfCharacter(a), hasLength(1));

    await state.activateQuickFlowEntry(
        _entry(monk, QuickFlowPhase.otherNights, 'protectedPlayer'),
        characters);
    expect((await state.assignActiveQuickFlowReminder(characters, b)).success,
        isTrue);
    expect(state.tokensOfCharacter(a), isEmpty);
    expect(state.tokensOfCharacter(b).single.quickId, 'save');
  });

  test('Poisoner reminder survives a night phase change', () async {
    final poisoner = _role(
      'poisoner',
      fraction: Fraction.minion,
      tokens: [_token('Poisoned', 'poisoned')],
      quickFlow: {
        'otherNights': [_reminder('poisonedPlayer', 'poisoned')],
      },
    );
    final target = _role('washerwoman', id: 'target');
    final characters = [poisoner, target];
    final state = await _nightState(poisoner, characters);

    await state.assignActiveQuickFlowReminder(characters, target);
    await state.nextNightState(characters);

    expect(state.tokensOfCharacter(target).single.quickId, 'poisoned');
  });

  test('Harpy advances Mad to 2nd and prepares the recipient-safe info',
      () async {
    final harpy = _role(
      'harpy',
      fraction: Fraction.minion,
      tokens: [_token('Mad', 'mad'), _token('2nd', 'second')],
      quickFlow: {
        'otherNights': [
          _reminder('madPlayer', 'mad', distinctFrom: ['secondPlayer']),
          _reminder('secondPlayer', 'second', distinctFrom: ['madPlayer']),
          {
            'id': 'showHarpy',
            'type': 'showInfo',
            'recipient': {'type': 'reminderTarget', 'stepId': 'madPlayer'},
            'presentation': {
              'kind': 'characterSelectedYouMadAboutPlayer',
              'sourceRoleId': 'harpy',
              'playerStep': 'secondPlayer',
            },
            'requires': ['madPlayer', 'secondPlayer'],
          },
        ],
      },
    );
    final a = _role('washerwoman', id: 'a', playerName: 'A');
    final b = _role('investigator', id: 'b', playerName: 'B');
    final characters = [harpy, a, b];
    final state = await _nightState(harpy, characters);

    await state.assignActiveQuickFlowReminder(characters, a);
    expect(state.activeQuickFlowReminder(characters)?.step.id, 'secondPlayer');
    await state.assignActiveQuickFlowReminder(characters, b);
    final infoEntry = _entry(harpy, QuickFlowPhase.otherNights, 'showHarpy');

    expect(state.isQuickFlowInfoReady(infoEntry, characters, characters), true);
    final info = state.buildQuickFlowInfo(infoEntry, characters, characters);
    expect(info?.players.single.id, 'b');
    expect(info?.sourceCharacter?.roleId, 'harpy');
  });

  test('Cerenovus uses a separate manual character token for prepared info',
      () async {
    final cerenovus = _role(
      'cerenovus',
      fraction: Fraction.minion,
      tokens: [_token('Mad', 'mad')],
      quickFlow: {
        'otherNights': [
          _reminder('madPlayer', 'mad'),
          {
            'id': 'madCharacter',
            'type': 'reminderCharacterToken',
            'selection': {'type': 'manual'},
            'allowedFractions': ['townsfolk', 'outsider'],
            'allowManualOverride': true,
          },
          {
            'id': 'showMad',
            'type': 'showInfo',
            'recipient': {'type': 'reminderTarget', 'stepId': 'madPlayer'},
            'presentation': {
              'kind': 'characterSelectedYouMadAboutCharacter',
              'sourceRoleId': 'cerenovus',
              'characterStep': 'madCharacter',
            },
            'requires': ['madPlayer', 'madCharacter'],
          },
        ],
      },
    );
    final target = _role('washerwoman', id: 'target');
    final chosen = _role('investigator', id: 'chosen');
    final characters = [cerenovus, target];
    final allCharacters = [cerenovus, target, chosen];
    final state = await _nightState(cerenovus, characters);

    await state.assignActiveQuickFlowReminder(characters, target);
    final characterEntry =
        _entry(cerenovus, QuickFlowPhase.otherNights, 'madCharacter');
    expect(await state.setQuickFlowSelectedCharacter(characterEntry, chosen),
        isTrue);
    final infoEntry = _entry(cerenovus, QuickFlowPhase.otherNights, 'showMad');
    final info = state.buildQuickFlowInfo(
      infoEntry,
      characters,
      allCharacters,
    );

    expect(info?.selectedCharacter?.roleId, 'investigator');
    expect(info?.players, isEmpty);
  });

  test('Washerwoman and Investigator setup drive automatic character tokens',
      () async {
    Future<void> verify({
      required String ownerRole,
      required String targetStep,
      required String targetToken,
      required Fraction fraction,
      required String targetRole,
    }) async {
      final owner = _role(
        ownerRole,
        tokens: [
          _token(targetToken, targetToken),
          _token('Wrong', 'wrong'),
        ],
        quickFlow: {
          'setup': [
            _reminder(targetStep, targetToken,
                operation: 'setOnce',
                allowedTargets: {
                  'fractions': [fraction.name]
                }),
            _reminder('wrongTarget', 'wrong',
                operation: 'setOnce', distinctFrom: [targetStep]),
          ],
          'firstNight': [
            {
              'id': 'shownCharacter',
              'type': 'reminderCharacterToken',
              'selection': {
                'type': 'fromReminderTarget',
                'stepId': targetStep,
              },
              'allowedFractions': [fraction.name],
              'allowManualOverride': true,
            },
          ],
        },
      );
      final actual =
          _role(targetRole, id: '$ownerRole-actual', fraction: fraction);
      final wrong = _role('washerwoman', id: '$ownerRole-wrong');
      final characters = [owner, actual, wrong];
      final state = await _state();
      state.initUnusedGameTokens(characters);

      await state.assignActiveQuickFlowReminder(characters, actual);
      await state.assignActiveQuickFlowReminder(characters, wrong);
      final shown = _entry(owner, QuickFlowPhase.firstNight, 'shownCharacter');

      expect(
        state.quickFlowSelectedCharacter(shown, characters, characters)?.roleId,
        targetRole,
      );
    }

    await verify(
      ownerRole: 'washerwoman',
      targetStep: 'townsfolkTarget',
      targetToken: 'townsfolk',
      fraction: Fraction.townsfolk,
      targetRole: 'investigator',
    );
    await verify(
      ownerRole: 'investigator',
      targetStep: 'minionTarget',
      targetToken: 'minion',
      fraction: Fraction.minion,
      targetRole: 'poisoner',
    );
  });

  test('Innkeeper keeps both Safe instances and restricts Is drunk', () async {
    final innkeeper = _role(
      'innkeeper',
      tokens: [
        _token('Safe', 'safe_1'),
        _token('Safe', 'safe_2'),
        _token('Is drunk', 'is_drunk'),
      ],
      quickFlow: {
        'otherNights': [
          _reminder('safe1', 'safe_1', distinctFrom: ['safe2']),
          _reminder('safe2', 'safe_2', distinctFrom: ['safe1']),
          _reminder('drunkPlayer', 'is_drunk', allowedTargets: {
            'mustMatchOneOf': ['safe1', 'safe2']
          }),
        ],
      },
    );
    final a = _role('washerwoman', id: 'a');
    final b = _role('investigator', id: 'b');
    final c = _role('chef', id: 'c');
    final characters = [innkeeper, a, b, c];
    final state = await _nightState(innkeeper, characters);

    await state.assignActiveQuickFlowReminder(characters, a);
    await state.assignActiveQuickFlowReminder(characters, b);
    final invalid = await state.assignActiveQuickFlowReminder(characters, c);
    expect(invalid.success, true);
    expect(invalid.warning, QuickFlowAssignmentFailure.invalidTarget);
    expect(state.tokensOfCharacter(c).single.quickId, 'is_drunk');
    expect(state.tokensOfCharacter(a).map((token) => token.quickId),
        contains('safe_1'));
    expect(state.tokensOfCharacter(b).single.quickId, 'safe_2');
  });

  test('Noble and Knight physical token slots stay independently editable',
      () async {
    Future<void> verify(String roleId, int count) async {
      final tokens = [
        for (var index = 1; index <= count; index++)
          _token('Know', 'know_$index'),
      ];
      final owner = _role(
        roleId,
        tokens: tokens,
        quickFlow: {
          'setup': [
            for (var index = 1; index <= count; index++)
              _reminder('know$index', 'know_$index', operation: 'setOnce'),
          ],
        },
      );
      final targets = [
        for (var index = 1; index <= count; index++)
          _role('target$index', id: '$roleId-target-$index'),
      ];
      final characters = [owner, ...targets];
      final state = await _state();
      state.initUnusedGameTokens(characters);
      for (final target in targets) {
        await state.assignActiveQuickFlowReminder(characters, target);
      }
      expect(
        targets
            .expand(state.tokensOfCharacter)
            .map((token) => token.quickId)
            .toSet(),
        hasLength(count),
      );
    }

    await verify('knight', 2);
    await verify('noble', 3);
  });

  test('manual menu mutations immediately change QuickFlow targets', () async {
    final owner = _role(
      'washerwoman',
      tokens: [_token('Townsfolk', 'townsfolk')],
      quickFlow: {
        'setup': [
          _reminder('townsfolkTarget', 'townsfolk', operation: 'setOnce')
        ],
      },
    );
    final a = _role('investigator', id: 'a');
    final b = _role('chef', id: 'b');
    final characters = [owner, a, b];
    final state = await _state();
    state.initUnusedGameTokens(characters);
    final entry = _entry(owner, QuickFlowPhase.setup, 'townsfolkTarget');
    final token = state.quickFlowToken(entry)!;

    await state.addTokenToCharacter(characters, a, token);
    expect(state.quickFlowTarget(entry, characters)?.id, 'a');
    await state.addTokenToCharacter(characters, b, token);
    expect(state.quickFlowTarget(entry, characters)?.id, 'b');
  });

  test('QuickFlow state and token identity survive saving and reloading',
      () async {
    SharedPreferences.setMockInitialValues({});
    final owner = _role(
      'washerwoman',
      tokens: [_token('Townsfolk', 'townsfolk')],
      quickFlow: {
        'setup': [
          _reminder('townsfolkTarget', 'townsfolk', operation: 'setOnce')
        ],
      },
    );
    final target = _role('investigator', id: 'target');
    final characters = [owner, target];
    final first = GameStateService();
    await first.ready;
    first.initUnusedGameTokens(characters);
    await first.assignActiveQuickFlowReminder(characters, target);

    final restoredOwner = Character.fromJson(owner.toJson());
    final restoredTarget = Character.fromJson(target.toJson());
    final restoredCharacters = [restoredOwner, restoredTarget];
    final restored = GameStateService();
    await restored.ready;
    restored.initUnusedGameTokens(restoredCharacters);
    final entry =
        _entry(restoredOwner, QuickFlowPhase.setup, 'townsfolkTarget');

    expect(restored.quickFlowTarget(entry, restoredCharacters)?.id, 'target');
    expect(restored.tokensOfCharacter(restoredTarget).single,
        same(restoredOwner.tokens.single));
  });

  test('legacy saves without quick ids reconnect and roles without flow work',
      () async {
    final owner = _role(
      'washerwoman',
      tokens: [_token('Townsfolk', 'townsfolk')],
      quickFlow: {
        'setup': [
          _reminder('townsfolkTarget', 'townsfolk', operation: 'setOnce')
        ],
      },
    );
    final target = _role('investigator', id: 'target');
    final legacyToken = {
      'name': 'Townsfolk',
      'image': 'Icon_townsfolk',
      'unlimited': false,
      'needsSetup': false,
    };
    final state = await _state(initial: {
      'character_tokens': jsonEncode({
        'target': [legacyToken]
      }),
    });
    final characters = [owner, target];
    state.initUnusedGameTokens(characters);
    final entry = _entry(owner, QuickFlowPhase.setup, 'townsfolkTarget');

    expect(state.quickFlowTarget(entry, characters)?.id, 'target');
    expect(state.quickFlowEntries([_role('chef')]), isEmpty);
  });

  test('night constraints compare against the preserved previous target',
      () async {
    final exorcist = _role(
      'exorcist',
      tokens: [_token('Chosen', 'chosen')],
      quickFlow: {
        'otherNights': [
          {
            ..._reminder('chosenPlayer', 'chosen'),
            'nightConstraint': 'differentFromPreviousNight',
          }
        ],
      },
    );
    final a = _role('washerwoman', id: 'a');
    final b = _role('investigator', id: 'b');
    final characters = [exorcist, a, b];
    final state = await _nightState(exorcist, characters);
    final entry = _entry(exorcist, QuickFlowPhase.otherNights, 'chosenPlayer');
    await state.addTokenToCharacter(
      characters,
      a,
      state.quickFlowToken(entry)!,
    );

    final repeated = await state.assignActiveQuickFlowReminder(characters, a);
    expect(repeated.success, isTrue);
    expect(
      repeated.warning,
      QuickFlowAssignmentFailure.previousNightTarget,
    );
    await state.activateQuickFlowEntry(entry, characters);
    expect((await state.assignActiveQuickFlowReminder(characters, b)).success,
        isTrue);
  });

  test('grouped append steps retain their individual chosen targets', () async {
    final shabaloth = _role(
      'shabaloth',
      fraction: Fraction.demon,
      tokens: [_token('Dead', 'dead', unlimited: true)],
      quickFlow: {
        'otherNights': [
          {
            ..._reminder('attack1', 'dead', operation: 'append'),
            'group': 'attacks',
          },
          {
            ..._reminder('attack2', 'dead', operation: 'append'),
            'group': 'attacks',
          },
        ],
      },
    );
    final a = _role('washerwoman', id: 'a');
    final b = _role('investigator', id: 'b');
    final characters = [shabaloth, a, b];
    final state = await _nightState(shabaloth, characters);

    await state.assignActiveQuickFlowReminder(characters, a);
    await state.assignActiveQuickFlowReminder(characters, b);

    expect(
      state
          .quickFlowTargets(
            _entry(shabaloth, QuickFlowPhase.otherNights, 'attack1'),
            characters,
          )
          .single
          .id,
      'a',
    );
    expect(
      state
          .quickFlowTargets(
            _entry(shabaloth, QuickFlowPhase.otherNights, 'attack2'),
            characters,
          )
          .single
          .id,
      'b',
    );
  });

  test('setup character selections remain available when night one starts',
      () async {
    final stormCatcher = _role(
      'stormcatcher',
      quickFlow: {
        'setup': [
          {
            'id': 'favoredCharacter',
            'type': 'reminderCharacterToken',
            'selection': {'type': 'manual'},
            'allowedFractions': ['townsfolk'],
            'allowManualOverride': true,
          },
        ],
      },
    );
    final chosen = _role('washerwoman');
    final state = await _state();
    final entry =
        _entry(stormCatcher, QuickFlowPhase.setup, 'favoredCharacter');
    expect(await state.setQuickFlowSelectedCharacter(entry, chosen), isTrue);

    await state.startNewGame([stormCatcher]);

    expect(
      state.quickFlowSelectedCharacter(
        entry,
        [stormCatcher],
        [stormCatcher, chosen],
      )?.roleId,
      'washerwoman',
    );
  });

  test('Snake Charmer keeps both prepared role displays separate', () async {
    final snakeCharmer = _role(
      'snakecharmer',
      tokens: [_token('Chosen', 'chosen'), _token('Poisoned', 'poisoned')],
      quickFlow: {
        'otherNights': [
          _reminder('chosenPlayer', 'chosen'),
          _reminder('poisonedSnakeCharmer', 'poisoned', operation: 'setOnce'),
          {
            'id': 'demonCharacter',
            'type': 'reminderCharacterToken',
            'selection': {
              'type': 'fromReminderTarget',
              'stepId': 'chosenPlayer',
            },
            'allowManualOverride': true,
            'allowedFractions': ['demon'],
          },
          {
            'id': 'showNewDemon',
            'type': 'showInfo',
            'recipient': {'type': 'abilityOwner'},
            'presentation': {
              'kind': 'youAre',
              'characterStep': 'demonCharacter',
            },
            'requires': [
              'chosenPlayer',
              'demonCharacter',
              'poisonedSnakeCharmer',
            ],
            'showOnlyWhen': {'type': 'storytellerConfirmed'},
          },
          {
            'id': 'snakeCharmerCharacter',
            'type': 'reminderCharacterToken',
            'selection': {
              'type': 'fromReminderTarget',
              'stepId': 'poisonedSnakeCharmer',
            },
            'allowManualOverride': true,
            'allowedFractions': ['townsfolk'],
          },
          {
            'id': 'showNewSnakeCharmer',
            'type': 'showInfo',
            'recipient': {
              'type': 'reminderTarget',
              'stepId': 'poisonedSnakeCharmer',
            },
            'presentation': {
              'kind': 'youAre',
              'characterStep': 'snakeCharmerCharacter',
            },
            'requires': [
              'poisonedSnakeCharmer',
              'snakeCharmerCharacter',
            ],
            'showOnlyWhen': {'type': 'storytellerConfirmed'},
          },
        ],
      },
    );
    final demon = _role('imp', id: 'demon', fraction: Fraction.demon);
    final characters = [snakeCharmer, demon];
    final state = await _nightState(snakeCharmer, characters);

    await state.assignActiveQuickFlowReminder(characters, demon);
    final demonCharacter =
        _entry(snakeCharmer, QuickFlowPhase.otherNights, 'demonCharacter');
    expect(
      state
          .quickFlowSelectedCharacter(demonCharacter, characters, characters)
          ?.roleId,
      'imp',
    );

    await state.assignActiveQuickFlowReminder(characters, demon);
    final snakeCharacter = _entry(
      snakeCharmer,
      QuickFlowPhase.otherNights,
      'snakeCharmerCharacter',
    );
    expect(
      await state.setQuickFlowSelectedCharacter(snakeCharacter, snakeCharmer),
      isTrue,
    );

    final newDemon =
        _entry(snakeCharmer, QuickFlowPhase.otherNights, 'showNewDemon');
    final newSnakeCharmer = _entry(
      snakeCharmer,
      QuickFlowPhase.otherNights,
      'showNewSnakeCharmer',
    );
    await state.confirmQuickFlowInfo(newDemon);
    await state.confirmQuickFlowInfo(newSnakeCharmer);

    final demonInfo =
        state.buildQuickFlowInfo(newDemon, characters, characters)!;
    final snakeInfo =
        state.buildQuickFlowInfo(newSnakeCharmer, characters, characters)!;
    expect(demonInfo.recipient?.id, snakeCharmer.id);
    expect(demonInfo.characters.single.roleId, 'imp');
    expect(snakeInfo.recipient?.id, demon.id);
    expect(snakeInfo.characters.single.roleId, 'snakecharmer');
    expect(snakeCharmer.roleId, 'snakecharmer');
    expect(demon.roleId, 'imp');
  });

  test('Dreamer style displays keep multiple character tokens together',
      () async {
    final dreamer = _role(
      'dreamer',
      tokens: [_token('Chosen', 'chosen')],
      quickFlow: {
        'otherNights': [
          _reminder('chosenPlayer', 'chosen'),
          {
            'id': 'trueCharacter',
            'type': 'reminderCharacterToken',
            'selection': {
              'type': 'fromReminderTarget',
              'stepId': 'chosenPlayer',
            },
            'allowManualOverride': true,
          },
          {
            'id': 'otherCharacter',
            'type': 'reminderCharacterToken',
            'selection': {'type': 'manual'},
          },
          {
            'id': 'showDreamer',
            'type': 'showInfo',
            'recipient': {'type': 'abilityOwner'},
            'presentation': {
              'kind': 'playersAndCharacter',
              'playerStep': 'chosenPlayer',
              'characterSteps': ['trueCharacter', 'otherCharacter'],
            },
            'requires': [
              'chosenPlayer',
              'trueCharacter',
              'otherCharacter',
            ],
          },
        ],
      },
    );
    final chosen = _role('washerwoman', id: 'chosen');
    final falseCharacter =
        _role('imp', id: 'imp-catalog', fraction: Fraction.demon);
    final characters = [dreamer, chosen];
    final allCharacters = [...characters, falseCharacter];
    final state = await _nightState(dreamer, characters);

    await state.assignActiveQuickFlowReminder(characters, chosen);
    expect(
      await state.setQuickFlowSelectedCharacter(
        _entry(dreamer, QuickFlowPhase.otherNights, 'otherCharacter'),
        falseCharacter,
      ),
      isTrue,
    );
    final info = state.buildQuickFlowInfo(
      _entry(dreamer, QuickFlowPhase.otherNights, 'showDreamer'),
      characters,
      allCharacters,
    )!;

    expect(info.recipient?.id, dreamer.id);
    expect(info.players.single.id, chosen.id);
    expect(info.characters.map((character) => character.roleId),
        ['washerwoman', 'imp']);
  });

  test('multiple target players stay attached to their one presentation',
      () async {
    final owner = _role(
      'balloonist',
      tokens: [_token('Know', 'know', unlimited: true)],
      quickFlow: {
        'otherNights': [
          _reminder('targets', 'know', operation: 'append'),
          {
            'id': 'showTargets',
            'type': 'showInfo',
            'recipient': {'type': 'abilityOwner'},
            'presentation': {
              'kind': 'pointToPlayers',
              'playerSteps': ['targets'],
            },
            'requires': ['targets'],
          },
        ],
      },
    );
    final a = _role('washerwoman', id: 'a');
    final b = _role('investigator', id: 'b');
    final characters = [owner, a, b];
    final state = await _nightState(owner, characters);

    await state.assignActiveQuickFlowReminder(characters, a);
    await state.activateQuickFlowEntry(
      _entry(owner, QuickFlowPhase.otherNights, 'targets'),
      characters,
    );
    await state.assignActiveQuickFlowReminder(characters, b);
    final info = state.buildQuickFlowInfo(
      _entry(owner, QuickFlowPhase.otherNights, 'showTargets'),
      characters,
      characters,
    )!;

    expect(info.players.map((character) => character.id), ['a', 'b']);
    expect(info.recipient?.id, owner.id);
  });

  test('storyteller can skip and later confirm a conditional display',
      () async {
    final owner = _role(
      'conditional',
      quickFlow: {
        'otherNights': [
          {
            'id': 'conditionalInfo',
            'type': 'showInfo',
            'recipient': {'type': 'abilityOwner'},
            'presentation': {'kind': 'showCharacter'},
            'showOnlyWhen': {'type': 'storytellerConfirmed'},
          },
        ],
      },
    );
    final state = await _state();
    final entry = _entry(owner, QuickFlowPhase.otherNights, 'conditionalInfo');

    expect(state.quickFlowInfoNeedsConfirmation(entry), isTrue);
    await state.skipQuickFlowInfo(entry);
    expect(state.isQuickFlowInfoSkipped(entry), isTrue);
    expect(state.buildQuickFlowInfo(entry, [owner], [owner]), isNull);

    await state.confirmQuickFlowInfo(entry);
    expect(state.isQuickFlowInfoSkipped(entry), isFalse);
    expect(state.quickFlowInfoNeedsConfirmation(entry), isFalse);
  });

  test('a ready regular information display needs no confirmation popup',
      () async {
    final owner = _role(
      'regularInfo',
      quickFlow: {
        'otherNights': [
          {
            'id': 'showInfo',
            'type': 'showInfo',
            'recipient': {'type': 'abilityOwner'},
            'presentation': {'kind': 'showCharacter', 'infoToken': 'you_are'},
          },
        ],
      },
    );
    final state = await _state();
    final entry = _entry(owner, QuickFlowPhase.otherNights, 'showInfo');

    expect(state.isQuickFlowInfoReady(entry, [owner], [owner]), isTrue);
    expect(state.quickFlowInfoNeedsConfirmation(entry), isFalse);
    expect(
      state.buildQuickFlowInfo(entry, [owner], [owner])?.infoToken,
      Basictoken.you_are,
    );
  });
}
