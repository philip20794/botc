import 'dart:convert';

import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameRecord validRecord() {
  final start = DateTime.utc(2026, 1, 1, 12);
  final end = start.add(const Duration(minutes: 1));
  const roleIds = ['monk'];
  return GameRecord(
    gameId: 'game_0123456789abcdef',
    startedAt: start,
    endedAt: end,
    totalDuration: end.difference(start),
    playerCount: 1,
    winnerTeam: GameTeam.good,
    script: GameRecordScript(
      scriptId: 'script_0123456789',
      name: 'Test',
      isCustom: false,
      roleIds: roleIds,
      contentHash: GameRecordScript.contentHashForRoleIds(roleIds),
    ),
    players: const [
      GameRecordPlayer(
        anonymizedPlayerId: 'player_0123456789',
        position: 0,
        actualStartRoleId: 'monk',
        displayedStartRoleId: 'monk',
        startTeam: GameTeam.good,
        endRoleId: 'monk',
        endTeam: GameTeam.good,
      ),
    ],
    phases: [
      GameRecordPhase(
        phaseId: 'phase_0123456789',
        type: GameRecordPhaseType.night,
        round: 1,
        startedAt: start,
        endedAt: end,
        duration: end.difference(start),
      ),
    ],
    chronicleEvents: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'drops corrupt records, rejects invalid and duplicate records, and keeps interrupted uploads',
      () async {
    final record = validRecord();
    SharedPreferences.setMockInitialValues(<String, Object>{
      GameRecordUploadQueue.storageKey: [
        'not json',
        jsonEncode(record.toJson())
      ],
    });
    final queue = GameRecordUploadQueue();
    await queue.ready;
    expect(queue.records.single.gameId, record.gameId);
    expect(await queue.enqueue(record), isFalse, reason: 'duplicate');

    final invalid = GameRecord(
      gameId: 'bad',
      startedAt: record.startedAt,
      endedAt: record.endedAt,
      totalDuration: Duration.zero,
      playerCount: 0,
      winnerTeam: record.winnerTeam,
      script: record.script,
      players: const [],
      phases: const [],
      chronicleEvents: const [],
    );
    expect(await queue.enqueue(invalid), isFalse);

    final recoveredAfterInterruptedUpload = GameRecordUploadQueue();
    await recoveredAfterInterruptedUpload.ready;
    expect(
        recoveredAfterInterruptedUpload.records.single.gameId, record.gameId);
  });
}
