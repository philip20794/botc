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
    // A transaction serializes competing client uploads for the same document:
    // only a missing document is set, while an existing one is left untouched.
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (existing.exists) {
        return FirestoreGameDocumentCreateResult.alreadyExists;
      }
      transaction.set(reference, document);
      return FirestoreGameDocumentCreateResult.created;
    });
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
    if (!_validator.validate(record).isValid) {
      return const GameRecordPublishResult(GameRecordPublishOutcome.invalid);
    }

    final document = record.toJson();
    final serializedBytes = utf8.encode(jsonEncode(document)).length;
    if (serializedBytes > maxSerializedDocumentBytes) {
      return const GameRecordPublishResult(GameRecordPublishOutcome.tooLarge);
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
