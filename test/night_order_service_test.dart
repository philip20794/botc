import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StringAssetBundle extends CachingAssetBundle {
  final Map<String, String> assets;

  _StringAssetBundle(this.assets);

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw StateError('Missing test asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> englishRoles;

  setUpAll(() async {
    englishRoles = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Character role(String roleId, {String? id}) {
    final json = englishRoles.singleWhere((role) => role['roleId'] == roleId);
    return Character.fromJson({...json, 'id': id ?? '$roleId-instance'});
  }

  Character syntheticRole(
    String roleId, {
    String? id,
    List<double> firstNight = const [],
    List<double> otherNight = const [],
  }) {
    return Character(
      id: id ?? '$roleId-instance',
      roleId: roleId,
      name: roleId,
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_$roleId',
      fraction: Fraction.townsfolk,
      tokens: const [],
      wakeUpEveryNight: false,
      wakeUpAtFirstNight: false,
      gameset: const [Gameset.experimental],
      nightStateNumbersFirstNight: firstNight,
      nightStateNumbersOtherNights: otherNight,
      tipsAndTricks: const [],
      bluffs: const [],
    );
  }

  Future<GameStateService> createGameState({
    Map<String, Object> initialValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final scripts = ScriptService();
    final nightOrder = NightOrderService();
    await Future.wait([scripts.ready, nightOrder.ready]);
    final state = GameStateService(
      scriptService: scripts,
      nightOrderService: nightOrder,
    );
    await state.ready;
    return state;
  }

  test('prepared catalogs and both canonical orders validate', () async {
    final service = NightOrderService();
    await service.ready;

    expect(service.firstNightOrder, isNotEmpty);
    expect(service.otherNightOrder, isNotEmpty);
    expect(service.validateData(), isEmpty);
    expect(service.phaseIds,
        containsAll(<String>['dusk', 'minioninfo', 'demoninfo', 'dawn']));
  });

  test('filters canonical order by in-play role ids and expands duplicates',
      () async {
    final service = NightOrderService();
    await service.ready;
    final characters = <Character>[
      role('washerwoman', id: 'washer-1'),
      role('poisoner'),
      role('washerwoman', id: 'washer-2'),
      role('leviathan'),
    ];

    final first = service.stepsFor(
      nightCount: 1,
      gameCharacters: characters,
      regularPlayerCount: 7,
      isAlive: (_) => true,
    );
    expect(
      first.map((step) => step.orderId),
      orderedEquals(<String>[
        'dusk',
        'minioninfo',
        'demoninfo',
        'poisoner',
        'washerwoman',
        'washerwoman',
        'leviathan',
      ]),
    );
    expect(
        first.where((step) => step.roleId == 'washerwoman').map((s) => s.id),
        orderedEquals(<String>[
          'role:washerwoman:washer-1',
          'role:washerwoman:washer-2'
        ]));
  });

  test('following nights retain dead conditional roles and post-dawn roles',
      () async {
    final service = NightOrderService();
    await service.ready;
    final characters = <Character>[
      role('ravenkeeper'),
      role('professor'),
      role('leviathan'),
    ];

    final steps = service.stepsFor(
      nightCount: 2,
      gameCharacters: characters,
      regularPlayerCount: 7,
      isAlive: (_) => false,
    );
    expect(steps.map((step) => step.orderId), contains('ravenkeeper'));
    expect(steps.map((step) => step.orderId), contains('professor'));
    expect(steps.map((step) => step.orderId, isNot(contains('dawn')));
    expect(
      steps.indexWhere((step) => step.orderId == 'leviathan'),
      greaterThan(steps.indexWhere((step) => step.orderId == 'professor')),
      reason: 'Dawn remains an ordering boundary even though it no longer '
          'creates a second untimed sun screen.',
    );
  });

  test('team info phases respect player count and a living Poppy Grower',
      () async {
    final service = NightOrderService();
    await service.ready;
    final poppyGrower = role('poppygrower');

    List<String> phaseIds(int players, bool alive) => service
        .stepsFor(
          nightCount: 1,
          gameCharacters: [poppyGrower],
          regularPlayerCount: players,
          isAlive: (_) => alive,
        )
        .map((step) => step.orderId)
        .toList();

    expect(phaseIds(6, false), isNot(contains('minioninfo')));
    expect(phaseIds(6, false), isNot(contains('demoninfo')));
    expect(phaseIds(7, true), isNot(contains('minioninfo')));
    expect(phaseIds(7, true), isNot(contains('demoninfo')));
    expect(phaseIds(7, false), containsAll(['minioninfo', 'demoninfo']));
  });

  test('German instructions and phases fall back to English independently',
      () async {
    final bundle = _StringAssetBundle({
      'assets/night_order/order.json': jsonEncode({
        'firstNight': ['dusk', 'testrole'],
        'otherNight': ['dawn'],
        'phaseInstructions': {
          'dusk': {'en': 'English phase', 'de': ''},
          'dawn': {'en': 'Dawn', 'de': 'Morgengrauen'},
        },
      }),
      'assets/characters/en.json': jsonEncode([
        {
          'roleId': 'testrole',
          'name': 'English name',
          'nightInstructions': {
            'firstNight': 'English instruction',
            'otherNight': null,
          },
        }
      ]),
      'assets/characters/de.json': jsonEncode([
        {
          'roleId': 'testrole',
          'name': 'Deutscher Name',
          'nightInstructions': {'firstNight': '', 'otherNight': null},
        }
      ]),
    });
    final service = NightOrderService(bundle: bundle);
    await service.ready;
    final characterStep = NightStep.character(syntheticRole('testrole'));

    expect(service.titleFor(characterStep, 'de'), 'Deutscher Name');
    expect(
      service.instructionFor(characterStep, 1, 'de'),
      'English instruction',
    );
    expect(
      service.instructionFor(NightStep.phase('dusk'), 1, 'de'),
      'English phase',
    );
  });

  test('game state navigates exact steps forward and backward', () async {
    final state = await createGameState(initialValues: {
      'player_names': jsonEncode(List.generate(7, (index) => 'P$index')),
    });
    final characters = <Character>[role('poisoner'), role('washerwoman')];
    await state.startNewGame(characters);

    expect(state.currentNightStepId, 'phase:dusk');
    await state.nextNightState(characters);
    expect(state.currentNightStepId, 'phase:minioninfo');
    await state.nextNightState(characters);
    expect(state.currentNightStepId, 'phase:demoninfo');
    await state.nextNightState(characters);
    expect(state.currentNightStepId, 'role:poisoner:poisoner-instance');
    expect(state.isCharacterAwake(characters.first), isTrue);
    expect(state.isCharacterAwake(characters.last), isFalse);
    await state.previousNightState(characters);
    expect(state.currentNightStepId, 'phase:demoninfo');
  });

  test('info phases highlight current minion and demon instances only',
      () async {
    final state = await createGameState(initialValues: {
      'player_names': jsonEncode(List.generate(7, (index) => 'P$index')),
    });
    // These are the instances a custom script supplied for the current game;
    // the highlight must not use every role that happens to be in a catalog.
    final characters = <Character>[
      role('poisoner', id: 'custom-minion-1'),
      role('scarletwoman', id: 'custom-minion-2'),
      role('imp', id: 'custom-demon'),
      role('magician', id: 'custom-magician'),
      role('washerwoman', id: 'custom-town'),
    ];

    Future<void> advanceTo(String stepId) async {
      while (state.currentNightStepId != stepId) {
        await state.nextNightState(characters);
      }
    }

    await state.startNewGame(characters);
    await advanceTo('phase:minioninfo');
    expect(state.currentNightStepId, 'phase:minioninfo');
    expect(
      state.highlightedNightCharacters(characters).map((role) => role.id),
      orderedEquals(['custom-minion-1', 'custom-minion-2']),
      reason: 'Magician keeps its actual Townsfolk fraction for highlighting.',
    );

    await advanceTo('phase:demoninfo');
    expect(state.currentNightStepId, 'phase:demoninfo');
    expect(
      state.highlightedNightCharacters(characters).map((role) => role.id),
      orderedEquals(['custom-demon']),
    );

    await advanceTo('role:poisoner:custom-minion-1');
    expect(state.currentNightStepId, 'role:poisoner:custom-minion-1');
    expect(
      state.highlightedNightCharacters(characters).map((role) => role.id),
      orderedEquals(['custom-minion-1']),
    );
  });

  test('legacy saved Dawn resumes after the boundary before post-dawn roles',
      () async {
    final leviathan = role('leviathan');
    final state = await createGameState(initialValues: {
      'night_count': 2,
      'night_step_id': 'phase:dawn',
    });
    await state.synchronizeNightStep([leviathan]);

    expect(state.currentNightStepId, 'role:leviathan:leviathan-instance');
    expect(state.isDay(), isFalse);

    await state.nextNightState([leviathan]);
    expect(state.currentNightStepId, 'day');
    expect(state.isDay(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('day_started_at'), isNotNull);
  });

  test('last post-dawn role starts day timer on the next and only tap',
      () async {
    final leviathan = role('leviathan');
    final state = await createGameState();
    await state.startNewGame([leviathan]);

    // The canonical list still places Leviathan after ordinary night roles,
    // but does not expose an intermediate dawn/sun step.
    while (state.currentNightStepId !=
        'role:leviathan:leviathan-instance') {
      expect(state.isDay(), isFalse);
      expect(state.currentNightStepId, isNot('phase:dawn'));
      await state.nextNightState([leviathan]);
    }
    await state.nextNightState([leviathan]);
    expect(state.currentNightStepId, 'day');
    expect(state.dayElapsed.inSeconds, lessThan(2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('day_started_at'), isNotNull);
  });

  test('stable step survives restart and localized help matches the outline',
      () async {
    final washerwoman = role('washerwoman');
    final state = await createGameState();
    await state.startNewGame([washerwoman]);
    while (
        state.currentNightStepId != 'role:washerwoman:washerwoman-instance') {
      await state.nextNightState([washerwoman]);
    }

    final expectedGerman = (jsonDecode(
      await rootBundle.loadString('assets/characters/de.json'),
    ) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .singleWhere((entry) => entry['roleId'] == 'washerwoman')[
        'nightInstructions']['firstNight'] as String;
    expect(state.isCharacterAwake(washerwoman), isTrue);
    expect(
      state.getNightStateHelpText(
        washerwoman,
        gameCharacters: [washerwoman],
        languageCode: 'de',
      ),
      expectedGerman,
    );

    final prefs = await SharedPreferences.getInstance();
    final restored = await createGameState(initialValues: {
      'night_count': prefs.getInt('night_count')!,
      'night_step_id': prefs.getString('night_step_id')!,
    });
    await restored.synchronizeNightStep([washerwoman]);
    expect(
      restored.currentNightStepId,
      'role:washerwoman:washerwoman-instance',
    );
    expect(restored.isCharacterAwake(washerwoman), isTrue);
  });

  test('legacy decimal position migrates only when it is unambiguous',
      () async {
    final washerwoman = role('washerwoman');
    final legacyPosition = washerwoman.nightStateNumbersFirstNight.single;
    final migrated = await createGameState(initialValues: {
      'night_count': 1,
      'night_state_number': legacyPosition,
    });
    await migrated.synchronizeNightStep([washerwoman]);
    expect(
      migrated.currentNightStepId,
      'role:washerwoman:washerwoman-instance',
    );

    final ambiguous = await createGameState(initialValues: {
      'night_count': 1,
      'night_state_number': 42.5,
    });
    await ambiguous.synchronizeNightStep([
      syntheticRole('washerwoman', id: 'one', firstNight: const [42.5]),
      syntheticRole('poisoner', id: 'two', firstNight: const [42.5]),
    ]);
    expect(ambiguous.currentNightStepId, 'phase:dusk');
  });

  test('invalid and empty restored states move to a safe canonical step',
      () async {
    final state = await createGameState(initialValues: {
      'night_count': 2,
      'night_step_id': 'role:removed:old-instance',
    });
    await state.synchronizeNightStep(const []);
    expect(state.currentNightStepId, 'phase:dusk');

    await state.nextNightState(const []);
    expect(state.currentNightStepId, 'day');
    expect(state.isDay(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('day_started_at'), isNotNull);
    // The next tap starts the next night; it must not be needed to start
    // the daytime stopwatch.
    await state.nextNightState(const []);
    expect(state.currentNightStepId, 'phase:dusk');
    expect(state.nightCount, 3);
  });
}
