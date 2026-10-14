import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character character({
  required String id,
  required String roleId,
  required Fraction fraction,
  List<Token> tokens = const [],
}) =>
    Character(
      id: id,
      roleId: roleId,
      name: roleId,
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_$roleId',
      fraction: fraction,
      tokens: tokens,
      wakeUpEveryNight: true,
      wakeUpAtFirstNight: true,
      gameset: const [Gameset.trouble_brewing],
      nightStateNumbersFirstNight: const [1],
      nightStateNumbersOtherNights: const [1],
      tipsAndTricks: const [],
      bluffs: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('start atomically captures shared identity, script and Drunk setup',
      () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final scriptService = ScriptService();
    final chronicleService = ChronicleService();
    final state = GameStateService(
      scriptService: scriptService,
      chronicleService: chronicleService,
      now: () => now,
    );
    await Future.wait([state.ready, chronicleService.ready]);

    final shownRole = character(
      id: 'shown-role-instance',
      roleId: 'washerwoman',
      fraction: Fraction.townsfolk,
    );
    final drunk = character(
      id: 'drunk-instance',
      roleId: 'drunk',
      fraction: Fraction.outsider,
      tokens: [
        Token(
          name: 'Is the Drunk',
          image: 'Reminder_drunk',
          needsSetup: true,
          quickId: 'is_the_drunk',
        ),
      ],
    );
    await state.addTokenToCharacter(
      [shownRole, drunk],
      shownRole,
      drunk.tokens.single,
    );

    await state.startNewGame(
      [shownRole],
      completeSetupCharacters: [shownRole, drunk],
      scriptCatalog: [shownRole, drunk],
    );

    final capture = state.activeGameRecordCapture!;
    expect(state.gameStartedAt, now);
    expect(chronicleService.activeChronicle!.gameId, capture.gameId);
    expect(chronicleService.activeChronicle!.startedAt, now);
    expect(capture.startedAt, now);
    expect(capture.script.scriptId, ScriptService.troubleBrewingId);
    expect(capture.script.roleIds, contains('drunk'));
    expect(capture.players, hasLength(1));
    expect(capture.players.single.displayedStartRoleId, 'washerwoman');
    expect(capture.players.single.actualStartRoleId, 'drunk');
    expect(capture.players.single.startTeam, GameTeam.good);
    expect(capture.phases.single.type, GameRecordPhaseType.night);
    expect(capture.phases.single.startedAt, now);
  });

  test('phase timestamps survive restart and navigation does not duplicate',
      () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final role = character(
      id: 'poisoner-instance',
      roleId: 'poisoner',
      fraction: Fraction.minion,
    );
    final state = GameStateService(now: () => now);
    await state.ready;
    await state.startNewGame([role], scriptCatalog: [role]);

    now = now.add(const Duration(minutes: 4));
    await state.startDay([role]);
    expect(state.activeGameRecordCapture!.phases, hasLength(2));
    expect(
      state.activeGameRecordCapture!.phases.first.endedAt,
      DateTime.utc(2026, 10, 13, 20, 4),
    );

    now = now.add(const Duration(minutes: 1));
    await state.previousNightState([role]);
    await state.startDay([role]);
    expect(state.activeGameRecordCapture!.phases, hasLength(2));

    now = now.add(const Duration(minutes: 6));
    await state.nextNight([role]);
    final beforeBackNavigation = state.activeGameRecordCapture!;
    expect(beforeBackNavigation.phases, hasLength(3));
    expect(beforeBackNavigation.phases[1].endedAt, now);
    expect(beforeBackNavigation.phases.last.round, 2);

    await state.previousNight([role]);
    expect(state.activeGameRecordCapture!.phases, hasLength(3));

    final restored = GameStateService(now: () => now);
    await restored.ready;
    final restoredCapture = restored.activeGameRecordCapture!;
    expect(restored.gameStartedAt, DateTime.utc(2026, 10, 13, 20));
    expect(restoredCapture.gameId, beforeBackNavigation.gameId);
    expect(restoredCapture.phases, hasLength(3));
    expect(restoredCapture.phases.last.isOpen, isTrue);
    expect(restoredCapture.phases.last.startedAt, now);
  });

  test('end updates the original seats and emits a valid anonymous record',
      () async {
    var now = DateTime.now().toUtc();
    final chronicle = ChronicleService();
    final state = GameStateService(
      chronicleService: chronicle,
      now: () => now,
    );
    await Future.wait([state.ready, chronicle.ready]);
    final originalGood = character(
      id: 'original-good-instance',
      roleId: 'monk',
      fraction: Fraction.townsfolk,
    )..playerName = 'Must not be exported';
    final originalEvil = character(
      id: 'original-evil-instance',
      roleId: 'imp',
      fraction: Fraction.demon,
    );
    await state.startNewGame(
      [originalGood, originalEvil],
      scriptCatalog: [originalGood, originalEvil],
    );
    final stablePlayerIds = state.activeGameRecordCapture!.players
        .map((player) => player.anonymizedPlayerId)
        .toList();

    now = now.add(const Duration(minutes: 5));
    await state.startDay([originalGood, originalEvil]);
    final changedGood = character(
      id: 'replacement-instance',
      roleId: 'baron',
      fraction: Fraction.minion,
    );
    now = now.add(const Duration(minutes: 8));
    await state.endGame(
      winningTeam: 'evil',
      gameCharacters: [changedGood, originalEvil],
    );

    final record = state.lastCompletedGameRecord!;
    expect(const GameRecordValidator().validate(record).isValid, isTrue);
    expect(record.players.map((player) => player.anonymizedPlayerId),
        stablePlayerIds);
    expect(record.players.first.actualStartRoleId, 'monk');
    expect(record.players.first.endRoleId, 'baron');
    expect(record.players.first.startTeam, GameTeam.good);
    expect(record.players.first.endTeam, GameTeam.evil);
    expect(record.totalDuration, const Duration(minutes: 13));
    expect(
        jsonEncode(record.toJson()), isNot(contains('Must not be exported')));
  });

  test('Traveller alignment remains missing instead of being invented',
      () async {
    var now = DateTime.utc(2026, 10, 13, 20);
    final traveller = character(
      id: 'traveller-instance',
      roleId: 'gunslinger',
      fraction: Fraction.traveller,
    );
    final state = GameStateService(now: () => now);
    await state.ready;
    await state.startNewGame([traveller], scriptCatalog: [traveller]);
    expect(state.activeGameRecordCapture!.players.single.startTeam, isNull);

    now = now.add(const Duration(minutes: 3));
    await state.endGame(
      winningTeam: 'good',
      gameCharacters: [traveller],
    );

    expect(state.lastGameRecordCapture, isNull);
    expect(state.lastCompletedGameRecord, isNull);
    expect(state.pendingGameRecords, isEmpty);
  });
}
