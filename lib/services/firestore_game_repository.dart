import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';

/// Small abstraction so publishing behaviour can be tested without Firebase.
abstract interface class FirestoreGameDocumentWriter {
  Future<FirestoreGameDocumentCreateResult> createIfAbsent(
    String gameId,
    Map<String, dynamic> document,
  );
}

enum FirestoreGameDocumentCreateResult { created, alreadyExists }

class CloudFirestoreGameDocumentWriter implements FirestoreGameDocumentWriter {
  static const collectionName = 'games';

  final FirebaseFirestore _firestore;

  CloudFirestoreGameDocumentWriter({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<FirestoreGameDocumentCreateResult> createIfAbsent(
    String gameId,
    Map<String, dynamic> document,
  ) {
    final reference = _firestore.collection(collectionName).doc(gameId);
    // The Firestore rules allow creates, but categorically reject updates.
    // Avoid the Web SDK's transactional read/commit path: the server rules,
    // rather than a client transaction, guarantee immutability.
    //
    // Always read from the server. A cached document is not proof of an
    // acknowledged upload and must not clear the durable outbox.
    const serverOnly = GetOptions(source: Source.server);
    return _createIfAbsent(reference, document, serverOnly);
  }

  Future<FirestoreGameDocumentCreateResult> _createIfAbsent(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> document,
    GetOptions serverOnly,
  ) async {
    final before = await reference.get(serverOnly);
    if (before.exists) {
      return FirestoreGameDocumentCreateResult.alreadyExists;
    }

    try {
      // This is a CREATE while the document is absent. If a concurrent
      // client writes first, the immutable rules reject our attempted UPDATE.
      await reference.set(document);
      return FirestoreGameDocumentCreateResult.created;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'already-exists') {
        // A concurrent client may have created the same gameId. Confirm that
        // the document exists on the server before acknowledging the queue.
        // For genuine rules/permission errors on a missing document, rethrow.
        final after = await reference.get(serverOnly);
        if (after.exists) {
          return FirestoreGameDocumentCreateResult.alreadyExists;
        }
      }
      rethrow;
    }
  }
}

enum GameRecordPublishOutcome {
  published,
  alreadyPublished,
  invalid,
  tooLarge,
  retryLater,
}

class GameRecordPublishResult {
  final GameRecordPublishOutcome outcome;
  final Object? error;

  const GameRecordPublishResult(this.outcome, {this.error});

  bool get isConfirmed =>
      outcome == GameRecordPublishOutcome.published ||
      outcome == GameRecordPublishOutcome.alreadyPublished;
}

class GameRecordPublishBatchResult {
  final int confirmed;
  final int rejected;
  final int retainedForRetry;

  const GameRecordPublishBatchResult({
    required this.confirmed,
    required this.rejected,
    required this.retainedForRetry,
  });
}

/// Publishes immutable, privacy-safe [GameRecord] documents to Firestore.
///
/// The local outbox remains the source of retry data. Nothing is removed from
/// it until Firestore confirms a create, or confirms that this exact immutable
/// document was already created by an earlier attempt.
class FirestoreGameRepository {
  // Firestore permits documents up to 1 MiB. Keep a deliberate margin for the
  // wire representation, indexes and future schema additions.
  static const maxSerializedDocumentBytes = 900 * 1024;

  final FirestoreGameDocumentWriter _writer;
  final GameRecordValidator _validator;
  Future<GameRecordPublishBatchResult>? _activeBatch;

  FirestoreGameRepository({
    FirestoreGameDocumentWriter? writer,
    GameRecordValidator validator = const GameRecordValidator(),
  })  : _writer = writer ?? CloudFirestoreGameDocumentWriter(),
        _validator = validator;

  Future<GameRecordPublishResult> publish(GameRecord record) async {
    final document = record.toJson();
    final serializedBytes = utf8.encode(jsonEncode(document)).length;
    // Reject grossly oversized input before detailed schema validation;
    // otherwise a huge field would be reported as "invalid" instead of
    // "tooLarge" and needlessly consume validation work.
    if (serializedBytes > maxSerializedDocumentBytes) {
      return const GameRecordPublishResult(GameRecordPublishOutcome.tooLarge);
    }
    if (!_validator.validate(record).isValid) {
      return const GameRecordPublishResult(GameRecordPublishOutcome.invalid);
    }

    try {
      final result = await _writer.createIfAbsent(record.gameId, document);
      return GameRecordPublishResult(
        result == FirestoreGameDocumentCreateResult.created
            ? GameRecordPublishOutcome.published
            : GameRecordPublishOutcome.alreadyPublished,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        return const GameRecordPublishResult(
          GameRecordPublishOutcome.alreadyPublished,
        );
      }
      return GameRecordPublishResult(
        GameRecordPublishOutcome.retryLater,
        error: error,
      );
    } catch (error) {
      return GameRecordPublishResult(
        GameRecordPublishOutcome.retryLater,
        error: error,
      );
    }
  }

  /// Attempts every queued document once. Concurrent calls share one run, so
  /// queue notifications and startup retries cannot duplicate creates.
  Future<GameRecordPublishBatchResult> publishPending(
    GameRecordUploadQueue queue,
  ) {
    final activeBatch = _activeBatch;
    if (activeBatch != null) return activeBatch;

    final batch = _publishPending(queue);
    _activeBatch = batch;
    batch.whenComplete(() {
      if (identical(_activeBatch, batch)) _activeBatch = null;
    });
    return batch;
  }

  Future<GameRecordPublishBatchResult> _publishPending(
    GameRecordUploadQueue queue,
  ) async {
    await queue.ready;
    var confirmed = 0;
    var rejected = 0;
    var retainedForRetry = 0;

    // Work on a snapshot: queue changes are persisted independently and may
    // notify listeners while a confirmed entry is removed below.
    for (final record in List<GameRecord>.from(queue.records)) {
      final result = await publish(record);
      if (result.isConfirmed) {
        if (await queue.removeByGameId(record.gameId)) confirmed++;
      } else if (result.outcome == GameRecordPublishOutcome.invalid ||
          result.outcome == GameRecordPublishOutcome.tooLarge) {
        // Do not upload partial data and do not silently discard a complete
        // local report. It remains inspectable/retryable after future schema
        // changes, but is never sent in this state.
        rejected++;
      } else {
        retainedForRetry++;
      }
    }

    return GameRecordPublishBatchResult(
      confirmed: confirmed,
      rejected: rejected,
      retainedForRetry: retainedForRetry,
    );
  }
}
