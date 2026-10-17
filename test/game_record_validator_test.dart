import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = GameRecordValidator();

  GameRecord validRecord() {
    final startedAt = DateTime.utc(2026, 1, 1, 19);
    final nightEnd = startedAt.add(const Duration(minutes: 10));
    final dayEnd = nightEnd.add(const Duration(minutes: 20));
    const roles = ['drunk', 'imp', 'monk', 'traveller'];
    return GameRecord(
      gameId: 'game_0123456789abcdef',
      startedAt: startedAt,
      endedAt: dayEnd,
      totalDuration: dayEnd.difference(startedAt),
      playerCount: 2,
      winnerTeam: GameTeam.good,
      script: GameRecordScript(
        scriptId: 'custom_0123456789abcdef',
        name: 'Example script',
        isCustom: true,
        roleIds: roles,
        contentHash: GameRecordScript.contentHashForRoleIds(roles),
      ),
      players: const [
        GameRecordPlayer(
          anonymizedPlayerId: 'player_0123456789abcdef',
          position: 0,
          actualStartRoleId: 'drunk',
          displayedStartRoleId: 'monk',
          startTeam: GameTeam.good,
          endRoleId: 'imp',
          endTeam: GameTeam.evil,
        ),
        GameRecordPlayer(
          anonymizedPlayerId: 'player_fedcba9876543210',
          position: 1,
          actualStartRoleId: 'traveller',
          displayedStartRoleId: 'traveller',
          startTeam: GameTeam.evil,
          endRoleId: 'traveller',
          endTeam: GameTeam.good,
        ),
      ],
      phases: [
        GameRecordPhase(
          phaseId: 'phase_0123456789abcdef',
          type: GameRecordPhaseType.night,
          round: 1,
          startedAt: startedAt,
          endedAt: nightEnd,
          duration: nightEnd.difference(startedAt),
        ),
        GameRecordPhase(
          phaseId: 'phase_fedcba9876543210',
          type: GameRecordPhaseType.day,
          round: 1,
          startedAt: nightEnd,
          endedAt: dayEnd,
          duration: dayEnd.difference(nightEnd),
        ),
      ],
      chronicleEvents: [
        GameRecordChronicleEvent(
          eventId: 'event_0123456789abcdef',
          occurredAt: startedAt.add(const Duration(minutes: 2)),
          type: GameRecordChronicleEventType.nightInformation,
          phase: GameRecordEventPhase.night,
          round: 1,
          actorPlayerId: 'player_0123456789abcdef',
          targetPlayerIds: const ['player_fedcba9876543210'],
          data: GameRecordEventData(
            flags: const {'answer': true},
            playerIds: const {
              'chosenPlayers': ['player_fedcba9876543210'],
            },
            tokenIds: const {
              'reminder': ['is_drunk'],
            },
          ),
        ),
      ],
    );
  }

  test('accepts a complete anonymised record with Drunk, Traveller and swaps',
      () {
    final record = validRecord();

    expect(validator.validate(record).isValid, isTrue);
    expect(GameRecord.fromJson(record.toJson()).toJson(), record.toJson());
  });

  test('rejects an invalid winner, duration and script hash from JSON', () {
    final json = validRecord().toJson();
    json['winnerTeam'] = 'neutral';
    expect(() => GameRecord.fromJson(json), throwsFormatException);

    final record = validRecord();
    final invalidDuration = GameRecord(
      gameId: record.gameId,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      totalDuration: const Duration(seconds: 1),
      playerCount: record.playerCount,
      winnerTeam: record.winnerTeam,
      script: GameRecordScript(
        scriptId: record.script.scriptId,
        name: record.script.name,
        isCustom: record.script.isCustom,
        roleIds: record.script.roleIds,
        contentHash: '0' * 64,
      ),
      players: record.players,
      phases: record.phases,
      chronicleEvents: record.chronicleEvents,
    );
    final result = validator.validate(invalidDuration);
    expect(result.isValid, isFalse);
    expect(result.issues.map((issue) => issue.path),
        containsAll(['totalDurationMs', 'script.contentHash']));
  });

  test('enforces published Firestore document bounds before upload', () {
    final longNameJson = validRecord().toJson();
    (longNameJson['script'] as Map<String, dynamic>)['name'] = 'x' * 129;
    final longName = GameRecord.fromJson(longNameJson);
    expect(
      validator.validate(longName).issues.map((issue) => issue.path),
      contains('script.name'),
    );

    final tooManyPlayersJson = validRecord().toJson();
    final samplePlayer = (tooManyPlayersJson['players'] as List).first
        as Map<String, dynamic>;
    tooManyPlayersJson['playerCount'] = 21;
    tooManyPlayersJson['players'] = List.generate(
      21,
      (index) => {
        ...samplePlayer,
        'anonymizedPlayerId': 'player_${index.toString().padLeft(20, '0')}',
        'position': index,
      },
    );
    final tooManyPlayers = GameRecord.fromJson(tooManyPlayersJson);
    expect(
      validator.validate(tooManyPlayers).issues.map((issue) => issue.path),
      contains('playerCount'),
    );
  });

  test('rejects missing consistency for players, phases and event references',
      () {
    final record = validRecord();
    final invalid = GameRecord(
      gameId: record.gameId,
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      totalDuration: record.totalDuration,
      playerCount: 3,
      winnerTeam: record.winnerTeam,
      script: record.script,
      players: [record.players.first],
      phases: [
        record.phases.first,
        GameRecordPhase(
          phaseId: 'phase_aaaaaaaaaaaaaaaa',
          type: GameRecordPhaseType.night,
          round: 2,
          startedAt: record.phases.first.endedAt,
          endedAt: record.endedAt,
          duration: record.endedAt.difference(record.phases.first.endedAt),
        ),
      ],
      chronicleEvents: [
        GameRecordChronicleEvent(
          eventId: 'event_aaaaaaaaaaaaaaaa',
          occurredAt: record.startedAt.add(const Duration(minutes: 1)),
          type: GameRecordChronicleEventType.nightInformation,
          phase: GameRecordEventPhase.night,
          round: 1,
          actorPlayerId: 'player_unknown_0000',
        ),
      ],
    );

    final result = validator.validate(invalid);
    expect(result.isValid, isFalse);
    expect(result.issues.map((issue) => issue.path), contains('playerCount'));
    expect(result.issues.map((issue) => issue.path), contains('phases[1]'));
    expect(result.issues.map((issue) => issue.path),
        contains('chronicleEvents[0].actorPlayerId'));
  });
}
