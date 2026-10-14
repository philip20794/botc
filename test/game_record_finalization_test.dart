import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character role(
  String roleId,
  Fraction fraction, {
  String? id,
}) =>
    Character(
      id: id ?? '$roleId-instance',
      roleId: roleId,
      name: roleId,
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_$roleId',
      fraction: fraction,
      tokens: const [],
      wakeUpEveryNight: true,
      wakeUpAtFirstNight: true,
      gameset: const [Gameset.trouble_brewing],
      nightStateNumbersFirstNight: const [1],
      nightStateNumbersOtherNights: const [1],
      tipsAndTricks: const [],
      bluffs: const [],
    );

Future<({GameStateService state, GameRecordUploadQueue queue})> runningGame({
  required DateTime Function() now,
  ChronicleService? chronicle,
  List<Character>? characters,
}) async {
  final uploadQueue = GameRecordUploadQueue();
  final chronicleService = chronicle ?? ChronicleService();
  final state = GameStateService(
    chronicleService: chronicleService,
    gameRecordUploadQueue: uploadQueue,
    now: now,
  );
  await state.ready;
  final roster = characters ??
      [
        role('monk', Fraction.townsfolk),
        role('imp', Fraction.demon),
      ];
  await state.startNewGame(roster, scriptCatalog: roster);
  return (state: state, queue: uploadQueue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('complete game is validated and durably queued before reset', () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final game = await runningGame(now: () => now);
    now = now.add(const Duration(minutes: 12));

    await game.state.endGame(
      winningTeam: 'good',
      gameCharacters: [
        role('monk', Fraction.townsfolk),
        role('imp', Fraction.demon),
      ],
    );

    expect(game.queue.records, hasLength(1));
    final queued = game.queue.records.single;
    expect(const GameRecordValidator().validate(queued).isValid, isTrue);
    expect(queued.endedAt, now);
    expect(queued.totalDuration, const Duration(minutes: 12));
    expect(game.state.gameIsRunning(), isFalse);

    final restoredQueue = GameRecordUploadQueue();
    await restoredQueue.ready;
    expect(restoredQueue.records.single.toJson(), queued.toJson());
  });

  test('missing winner discards the whole statistics report', () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final chronicle = ChronicleService();
    final game = await runningGame(now: () => now, chronicle: chronicle);
    now = now.add(const Duration(minutes: 4));

    await game.state.endGame(
      gameCharacters: [
        role('monk', Fraction.townsfolk),
        role('imp', Fraction.demon),
      ],
    );

    expect(game.queue.records, isEmpty);
    expect(game.state.lastCompletedGameRecord, isNull);
    expect(game.state.activeGameRecordCapture, isNull);
    expect(game.state.lastGameRecordCapture, isNull);
    expect(chronicle.lastChronicle, isNotNull);
    expect(chronicle.lastChronicle!.winningTeam, isNull);
    expect(game.state.gameIsRunning(), isFalse);
  });

  test('missing start data archives locally but never queues statistics',
      () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final chronicle = ChronicleService();
    final queue = GameRecordUploadQueue();
    final character = role('imp', Fraction.demon);
    await chronicle.startNewGame([character], startedAt: now);
    final state = GameStateService(
      chronicleService: chronicle,
      gameRecordUploadQueue: queue,
      now: () => now,
    );
    await state.ready;
    now = now.add(const Duration(minutes: 2));

    await state.endGame(
      winningTeam: 'evil',
      gameCharacters: [character],
    );

    expect(queue.records, isEmpty);
    expect(state.lastCompletedGameRecord, isNull);
    expect(chronicle.lastChronicle, isNotNull);
  });

  test('concurrent and repeated completion only enqueue one report', () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final roster = [
      role('monk', Fraction.townsfolk),
      role('imp', Fraction.demon),
    ];
    final game = await runningGame(now: () => now, characters: roster);
    now = now.add(const Duration(minutes: 9));

    await Future.wait([
      game.state.endGame(winningTeam: 'evil', gameCharacters: roster),
      game.state.endGame(winningTeam: 'evil', gameCharacters: roster),
    ]);
    await game.state.endGame(winningTeam: 'evil', gameCharacters: roster);

    expect(game.queue.records, hasLength(1));
    expect(game.queue.records.single.endedAt, now);
  });

  test('role and Chronicle snapshot are completed before character reset',
      () async {
    var now = DateTime.now().toUtc();
    final chronicle = ChronicleService();
    final queue = GameRecordUploadQueue();
    final characters = CharacterService(chronicleService: chronicle);
    await characters.init();
    characters.addCharacter(role('monk', Fraction.townsfolk));
    characters.addCharacter(role('imp', Fraction.demon));
    await Future<void>.delayed(Duration.zero);
    final state = GameStateService(
      chronicleService: chronicle,
      gameRecordUploadQueue: queue,
      now: () => now,
    );
    await state.ready;
    await state.startNewGame(
      characters.gameCharactersWithoutDrunkAndFabled,
      completeSetupCharacters: characters.gameCharacters,
      scriptCatalog: characters.allCharacters,
    );
    final oldRole = characters.gameCharacters.first;
    final replacementId = characters.changeCharacter(
      oldRole,
      role('baron', Fraction.minion),
    );
    await state.giveAllTokensFromCharacterAToCharacterB(
      characters.gameCharacters,
      oldRole,
      replacementId,
    );
    now = now.add(const Duration(minutes: 6));

    await state.endGame(
      winningTeam: 'evil',
      characterService: characters,
    );

    final queued = queue.records.single;
    expect(queued.players.first.endRoleId, 'baron');
    expect(
      queued.chronicleEvents
          .map((event) => event.type)
          .contains(GameRecordChronicleEventType.characterChanged),
      isTrue,
    );
    expect(characters.gameCharacters.first.roleId, 'monk');
    expect(state.gameIsRunning(), isFalse);
  });
}
