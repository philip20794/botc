import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/firestore_game_repository.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeFirestoreGameDocumentWriter implements FirestoreGameDocumentWriter {
  final Map<String, Map<String, dynamic>> documents = {};
  bool failWrites = false;
  int createCalls = 0;

  @override
  Future<FirestoreGameDocumentCreateResult> createIfAbsent(
    String gameId,
    Map<String, dynamic> document,
  ) async {
    createCalls++;
    if (failWrites) throw StateError('offline');
    if (documents.containsKey(gameId)) {
      return FirestoreGameDocumentCreateResult.alreadyExists;
    }
    documents[gameId] = Map<String, dynamic>.from(document);
    return FirestoreGameDocumentCreateResult.created;
  }
}

GameRecord completeRecord({String scriptName = 'Test script'}) {
  final startedAt = DateTime.utc(2026, 10, 13, 20);
  final endedAt = startedAt.add(const Duration(minutes: 10));
  const roleIds = ['monk'];
  return GameRecord(
    gameId: 'game_0123456789',
    startedAt: startedAt,
    endedAt: endedAt,
    totalDuration: endedAt.difference(startedAt),
    playerCount: 1,
    winnerTeam: GameTeam.good,
    script: GameRecordScript(
      scriptId: 'script_0123456789',
      name: scriptName,
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
        startedAt: startedAt,
        endedAt: endedAt,
        duration: endedAt.difference(startedAt),
      ),
    ],
    chronicleEvents: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('creates exactly one validated immutable game document', () async {
    final writer = FakeFirestoreGameDocumentWriter();
    final repository = FirestoreGameRepository(writer: writer);
    final record = completeRecord();

    final first = await repository.publish(record);
    final retry = await repository.publish(record);

    expect(first.outcome, GameRecordPublishOutcome.published);
    expect(retry.outcome, GameRecordPublishOutcome.alreadyPublished);
    expect(writer.documents, hasLength(1));
    expect(writer.documents[record.gameId]!['gameId'], record.gameId);
    expect(writer.documents[record.gameId]!.containsKey('playerName'), isFalse);
    expect(writer.documents[record.gameId]!.containsKey('notes'), isFalse);
  });

  test('never sends invalid or oversized records', () async {
    final writer = FakeFirestoreGameDocumentWriter();
    final repository = FirestoreGameRepository(writer: writer);
    final valid = completeRecord();
    final invalid = GameRecord(
      gameId: valid.gameId,
      startedAt: valid.startedAt,
      endedAt: valid.endedAt,
      totalDuration: const Duration(seconds: 1),
      playerCount: valid.playerCount,
      winnerTeam: valid.winnerTeam,
      script: valid.script,
      players: valid.players,
      phases: valid.phases,
      chronicleEvents: valid.chronicleEvents,
    );
    final oversized = completeRecord(
      scriptName:
          'x' * (FirestoreGameRepository.maxSerializedDocumentBytes + 1),
    );

    expect(
      (await repository.publish(invalid)).outcome,
      GameRecordPublishOutcome.invalid,
    );
    expect(
      (await repository.publish(oversized)).outcome,
      GameRecordPublishOutcome.tooLarge,
    );
    expect(writer.createCalls, 0);
  });

  test('retains failed uploads and removes only confirmed records', () async {
    final writer = FakeFirestoreGameDocumentWriter()..failWrites = true;
    final repository = FirestoreGameRepository(writer: writer);
    final queue = GameRecordUploadQueue();
    final record = completeRecord();
    await queue.enqueue(record);

    final failedBatch = await repository.publishPending(queue);
    expect(failedBatch.retainedForRetry, 1);
    expect(queue.records.map((item) => item.gameId), [record.gameId]);

    writer.failWrites = false;
    final successfulBatch = await repository.publishPending(queue);
    expect(successfulBatch.confirmed, 1);
    expect(queue.records, isEmpty);
    expect(writer.documents.keys, [record.gameId]);

    final restoredQueue = GameRecordUploadQueue();
    await restoredQueue.ready;
    expect(restoredQueue.records, isEmpty);
  });
}
