import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> characterJson({
  required String name,
  required String image,
  String? id,
  String? roleId,
  Fraction fraction = Fraction.minion,
  int numberOfExemplars = 1,
  bool variableNumberOfExemplars = false,
}) {
  return <String, dynamic>{
    if (id != null) 'id': id,
    if (roleId != null) 'roleId': roleId,
    'name': name,
    'descriptionShort': '$name short',
    'descriptionLong': '$name long',
    'howToRun': 'Run $name',
    'image': image,
    'fraction': fraction.name,
    'tokens': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': '$name reminder',
        'image': image,
        'unlimited': false,
        'needsSetup': false,
      },
    ],
    'wakeUpEveryNight': false,
    'wakeUpAtFirstNight': true,
    'playerName': '',
    'gameset': <String>['trouble_brewing'],
    'nightStateNumbersFirstNight': <double>[1.0],
    'nightStateNumbersOtherNights': <double>[],
    'help': '',
    'help2': '',
    'upsideDown': false,
    'tipsAndTricks': <String>[],
    'bluffs': <String>[],
    'numberOfExemplars': numberOfExemplars,
    'variableNumberOfExemplars': variableNumberOfExemplars,
    'possibleNrOfExemplars': <int>[1, 2],
  };
}

Future<CharacterService> createCharacterService() async {
  final service = CharacterService();
  await service.init();
  return service;
}

Future<GameStateService> createGameStateService() async {
  final service = GameStateService();
  await service.init();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Character identity serialization', () {
    test('preserves role and instance identity through JSON round-trips', () {
      final character = Character.fromJson(characterJson(
        name: 'Imp',
        image: 'Icon_imp',
        id: 'game-42-imp',
        roleId: 'imp',
      ));

      final restored = Character.fromJson(character.toJson());

      expect(restored.id, 'game-42-imp');
      expect(restored.roleId, 'imp');
      expect(restored.image, 'Icon_imp');
    });

    test('reads pre-roleId and pre-id data without losing stable role identity',
        () {
      final english = Character.fromJson(
          characterJson(name: 'Imp', image: 'Icon_imp')
            ..remove('variableNumberOfExemplars'));
      final german = Character.fromJson(
          characterJson(name: 'Kobold', image: 'Icon_imp')
            ..remove('variableNumberOfExemplars'));

      expect(english.id, 'Icon_imp');
      expect(english.roleId, 'imp');
      expect(german.roleId, english.roleId);
    });

    test('converts legacy image-based IDs to official script IDs', () {
      expect(Character.roleIdFromImage('Icon_snakecharmer'), 'snakecharmer');
      expect(Character.roleIdFromImage('Icon_fortuneteller'), 'fortuneteller');
      expect(Character.roleIdFromImage('Icon_spiritofivory'), 'spiritofivory');
      expect(Character.roleIdFromImage('Icon_revolutionary'), 'revolutionary');

      final migrated = Character.fromJson(characterJson(
        name: 'Imp',
        image: 'Icon_imp',
        id: 'existing-instance-id',
        roleId: 'Icon_imp',
      ));

      expect(migrated.roleId, 'imp');
      expect(migrated.id, 'existing-instance-id');
    });
  });

  test('migrates realistic duplicate legacy instances and keeps old state',
      () async {
    final legacyCharacter = characterJson(
      name: 'Legion',
      image: 'Icon_legion',
      id: 'Icon_legion-1',
      roleId: 'Icon_legion',
      numberOfExemplars: 2,
      variableNumberOfExemplars: true,
    );
    final legacyList = jsonEncode(<Map<String, dynamic>>[
      legacyCharacter,
      Map<String, dynamic>.from(legacyCharacter),
    ]);
    final legacyToken = <String, dynamic>{
      'name': 'Legion reminder',
      'image': 'Icon_legion',
      'unlimited': false,
      'needsSetup': false,
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'character_list': legacyList,
      'character_list_backup': legacyList,
      'character_tokens': jsonEncode(<String, Object>{
        'Icon_legion-1': <Map<String, dynamic>>[legacyToken],
      }),
      'character_alive_state': jsonEncode(<String, bool>{
        'Icon_legion-1': false,
      }),
    });

    final characters = await createCharacterService();
    final state = await createGameStateService();

    expect(characters.gameCharacters.map((character) => character.id),
        <String>['Icon_legion-1', 'Icon_legion-1-1']);
    expect(characters.gameCharactersBackup.map((character) => character.id),
        <String>['Icon_legion-1', 'Icon_legion-1-1']);
    expect(
        identical(characters.gameCharacters.first,
            characters.gameCharactersBackup.first),
        isFalse);
    expect(
        state.tokensOfCharacter(characters.gameCharacters.first), hasLength(1));
    expect(state.isCharacterAlive(characters.gameCharacters.first), isFalse);
    expect(state.tokensOfCharacter(characters.gameCharacters.last), isEmpty);

    final reloaded = await createCharacterService();
    expect(reloaded.gameCharacters.map((character) => character.id),
        <String>['Icon_legion-1', 'Icon_legion-1-1']);
    final prefs = await SharedPreferences.getInstance();
    final migrated = jsonDecode(prefs.getString('character_list')!) as List;
    expect(migrated.first['roleId'], 'legion');
  });

  test('creates independent role instances and an independent backup',
      () async {
    final service = await createCharacterService();
    final catalogCharacter = Character.fromJson(characterJson(
      name: 'Legion',
      image: 'Icon_legion',
      numberOfExemplars: 2,
      variableNumberOfExemplars: true,
    ));

    service.addCharacter(catalogCharacter);

    expect(service.gameCharacters, hasLength(2));
    expect(service.gameCharacters.map((character) => character.id).toSet(),
        hasLength(2));
    expect(identical(service.gameCharacters[0], service.gameCharacters[1]),
        isFalse);
    expect(
        identical(service.gameCharacters[0], service.gameCharactersBackup[0]),
        isFalse);

    service.gameCharacters[0].playerName = 'Alice';
    service.flipCharacter(service.gameCharacters[0]);
    expect(service.gameCharacters[1].playerName, isEmpty);
    expect(service.gameCharacters[1].upsideDown, isFalse);
    expect(service.gameCharactersBackup[0].playerName, isEmpty);
    expect(service.gameCharactersBackup[0].upsideDown, isFalse);

    service.resetGameCharactersWithBackup();
    expect(service.gameCharacters[0].playerName, isEmpty);
    expect(service.gameCharacters[0].upsideDown, isFalse);
    expect(
        identical(service.gameCharacters[0], service.gameCharactersBackup[0]),
        isFalse);
  });

  test('character changes keep token and life state assigned and persisted',
      () async {
    final characters = await createCharacterService();
    final state = await createGameStateService();
    final oldRole = Character.fromJson(
        characterJson(name: 'Poisoner', image: 'Icon_poisoner'));
    final newRole =
        Character.fromJson(characterJson(name: 'Baron', image: 'Icon_baron'));
    characters.addCharacter(oldRole);
    final oldInstance = characters.gameCharacters.single;
    oldInstance.playerName = 'Alice';
    final token = oldInstance.tokens.single;
    await state
        .addTokenToCharacter(<Character>[oldInstance], oldInstance, token);
    await state.toggleCharacterAlive(oldInstance);

    final newId = characters.changeCharacter(oldInstance, newRole);
    await state.giveAllTokensFromCharacterAToCharacterB(
        characters.allCharacters, oldInstance, newId);
    final replacement = characters.gameCharacters.single;

    expect(replacement.roleId, 'baron');
    expect(replacement.playerName, 'Alice');
    expect(state.tokensOfCharacter(replacement), hasLength(1));
    expect(state.isCharacterAlive(replacement), isFalse);
    expect(state.tokensOfCharacter(oldInstance), isEmpty);

    final restoredState = await createGameStateService();
    expect(restoredState.tokensOfCharacter(replacement), hasLength(1));
    expect(restoredState.isCharacterAlive(replacement), isFalse);
  });

  test('character positions survive repeated saves and loads', () async {
    final characters = await createCharacterService();
    const positions = <int, Offset>{
      0: Offset(12.5, 42.0),
      1: Offset(80.0, 16.0),
    };

    characters.setCharacterPositions(positions);
    await Future<void>.delayed(Duration.zero);
    final firstReload = await createCharacterService();
    final secondReload = await createCharacterService();

    expect(firstReload.characterPositions, positions);
    expect(secondReload.characterPositions, positions);
  });

  test('Loric roles persist but are excluded from regular player cards',
      () async {
    final service = await createCharacterService();
    final loric = Character.fromJson(characterJson(
      name: 'Loric',
      image: 'Icon_loric',
      fraction: Fraction.loric,
    ));

    service.addCharacter(loric);
    service.setCharacterPositions(const <int, Offset>{0: Offset(33, 44)});
    await Future<void>.delayed(Duration.zero);

    final restored = await createCharacterService();
    expect(restored.gameCharacters.single.fraction, Fraction.loric);
    expect(restored.gameCharactersWithoutDrunkAndFabled, isEmpty);
    expect(restored.characterPositions[0], const Offset(33, 44));
  });

  test('token reset is persisted across repeated loads', () async {
    final state = await createGameStateService();
    final character = Character.fromJson(
        characterJson(name: 'Poisoner', image: 'Icon_poisoner'));
    await state.addTokenToCharacter(
        <Character>[character], character, character.tokens.single);
    expect(state.tokensOfCharacter(character), hasLength(1));

    await state.resetCharacterTokens(<Character>[character]);
    final firstReload = await createGameStateService();
    final secondReload = await createGameStateService();

    expect(firstReload.tokensOfCharacter(character), isEmpty);
    expect(secondReload.tokensOfCharacter(character), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('character_tokens')!), isEmpty);
  });
}
