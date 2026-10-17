import 'dart:convert';

import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Firestore-confirmed game from THIS app installation. Past uploads
/// cannot be reconstructed from Firestore without a device/account identity.
class GameRecordUploadReceipt {
  final String gameId;
  final String scriptName;
  final DateTime gameEndedAt;
  final DateTime confirmedAt;
  final bool alreadyExisted;

  const GameRecordUploadReceipt({
    required this.gameId,
    required this.scriptName,
    required this.gameEndedAt,
    required this.confirmedAt,
    required this.alreadyExisted,
  });

  factory GameRecordUploadReceipt.fromJson(Map<String, dynamic> json) =>
      GameRecordUploadReceipt(
        gameId: json['gameId'] as String,
        scriptName: json['scriptName'] as String,
        gameEndedAt: DateTime.parse(json['gameEndedAt'] as String),
        confirmedAt: DateTime.parse(json['confirmedAt'] as String),
        alreadyExisted: json['alreadyExisted'] == true,
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'scriptName': scriptName,
        'gameEndedAt': gameEndedAt.toIso8601String(),
        'confirmedAt': confirmedAt.toIso8601String(),
        'alreadyExisted': alreadyExisted,
      };
}

/// Last attempt for a queued game. Only known outcome codes are persisted;
/// neither raw exceptions nor player information are stored here.
class GameRecordUploadIssue {
  final String outcome;
  final String? errorCode;
  final DateTime attemptedAt;

  const GameRecordUploadIssue({
    required this.outcome,
    required this.attemptedAt,
    this.errorCode,
  });

  factory GameRecordUploadIssue.fromJson(Map<String, dynamic> json) =>
      GameRecordUploadIssue(
        outcome: json['outcome'] as String,
        errorCode: json['errorCode'] as String?,
        attemptedAt: DateTime.parse(json['attemptedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'outcome': outcome,
        if (errorCode != null) 'errorCode': errorCode,
        'attemptedAt': attemptedAt.toIso8601String(),
      };
}

/// Durable outbox for complete, validated game records.
///
/// Uploading is deliberately outside this service. Entries remain stored until
/// a future uploader explicitly acknowledges them.
class GameRecordUploadQueue extends ChangeNotifier {
  static const _storageKey = 'game_record_upload_queue_v1';
  static const _syncStatusKey = 'game_record_sync_status_v1';

  final GameRecordValidator _validator;
  final List<GameRecord> _records = [];
  final List<GameRecordUploadReceipt> _receipts = [];
  final Map<String, GameRecordUploadIssue> _issues = {};
  DateTime? _lastAttemptAt;
  bool _isUploading = false;
  late final Future<void> ready;

  GameRecordUploadQueue(
      {GameRecordValidator validator = const GameRecordValidator()})
      : _validator = validator {
    ready = _load();
  }

  List<GameRecord> get records => List.unmodifiable(_records);
  List<GameRecordUploadReceipt> get confirmedUploads =>
      List.unmodifiable(_receipts.reversed);
  int get confirmedUploadCount => _receipts.length;
  int get pendingCount => _records.length;
  int get failedCount =>
      _records.where((record) => _issues.containsKey(record.gameId)).length;
  DateTime? get lastAttemptAt => _lastAttemptAt;
  DateTime? get lastSuccessAt =>
      _receipts.isEmpty ? null : _receipts.last.confirmedAt;
  bool get isUploading => _isUploading;
  GameRecordUploadIssue? issueFor(String gameId) => _issues[gameId];

  void setUploading(bool value) {
    if (_isUploading == value) return;
    _isUploading = value;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_storageKey) ?? const [];
    final seen = <String>{};
    for (final item in encoded) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is! Map) continue;
        final record = GameRecord.fromJson(Map<String, dynamic>.from(decoded));
        if (_validator.validate(record).isValid && seen.add(record.gameId)) {
          _records.add(record);
        }
      } catch (_) {
        // Corrupt or incomplete entries are never treated as upload reports.
      }
    }
    final statusRaw = prefs.getString(_syncStatusKey);
    if (statusRaw != null) {
      try {
        final status = jsonDecode(statusRaw) as Map<String, dynamic>;
        final seen = <String>{};
        for (final item in (status['confirmed'] as List? ?? const [])) {
          if (item is! Map) continue;
          final receipt = GameRecordUploadReceipt.fromJson(
              Map<String, dynamic>.from(item));
          if (seen.add(receipt.gameId)) _receipts.add(receipt);
        }
        _receipts.sort((a, b) => a.confirmedAt.compareTo(b.confirmedAt));
        final issues = status['issues'];
        if (issues is Map) {
          for (final entry in issues.entries) {
            if (entry.key is! String || entry.value is! Map) continue;
            try {
              _issues[entry.key as String] = GameRecordUploadIssue.fromJson(
                  Map<String, dynamic>.from(entry.value as Map));
            } catch (_) {
              // A malformed status entry never prevents the outbox loading.
            }
          }
        }
        final attempted = status['lastAttemptAt'];
        if (attempted is String) {
          _lastAttemptAt = DateTime.tryParse(attempted);
        }
      } catch (_) {
        // Diagnostic metadata is optional; queued games remain recoverable.
      }
    }
    _issues.removeWhere((id, _) =>
        !_records.any((record) => record.gameId == id));
    notifyListeners();
  }

  Future<bool> _saveSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_syncStatusKey, jsonEncode({
      'confirmed': _receipts.map((receipt) => receipt.toJson()).toList(),
      'issues': _issues.map((id, issue) => MapEntry(id, issue.toJson())),
      if (_lastAttemptAt != null)
        'lastAttemptAt': _lastAttemptAt!.toIso8601String(),
    }));
  }

  /// Persists an actual Firestore result, then removes successful uploads
  /// from the outbox. Receipts are written first so a crash cannot lose proof
  /// of a successful upload. Retrying a queued receipt is idempotent.
  Future<bool> recordPublishResult(
    GameRecord record, {
    required String outcome,
    String? errorCode,
    DateTime? attemptedAt,
  }) async {
    await ready;
    final timestamp = attemptedAt ?? DateTime.now();
    _lastAttemptAt = timestamp;
    if (outcome == 'published' || outcome == 'alreadyPublished') {
      final alreadyRecorded = _receipts.any(
          (receipt) => receipt.gameId == record.gameId);
      if (!alreadyRecorded) {
        _receipts.add(GameRecordUploadReceipt(
          gameId: record.gameId,
          scriptName: record.script.name,
          gameEndedAt: record.endedAt,
          confirmedAt: timestamp,
          alreadyExisted: outcome == 'alreadyPublished',
        ));
      }
      _issues.remove(record.gameId);
      if (!await _saveSyncStatus()) return false;
      final removed = await removeByGameId(record.gameId);
      notifyListeners();
      return removed;
    }
    _issues[record.gameId] = GameRecordUploadIssue(
        outcome: outcome, errorCode: errorCode, attemptedAt: timestamp);
    await _saveSyncStatus();
    notifyListeners();
    return false;
  }

  /// Returns false for an invalid record or a game that is already queued.
  Future<bool> enqueue(GameRecord record) async {
    await ready;
    if (!_validator.validate(record).isValid ||
        _records.any((item) => item.gameId == record.gameId)) {
      return false;
    }
    final updated = List<GameRecord>.from(_records)..add(record);
    final prefs = await SharedPreferences.getInstance();
    final persisted = await prefs.setStringList(
      _storageKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
    if (!persisted) return false;
    _records
      ..clear()
      ..addAll(updated);
    notifyListeners();
    return true;
  }

  /// Removes an entry only after a remote publisher has confirmed that its
  /// immutable document exists. A failed local write leaves the outbox intact.
  Future<bool> removeByGameId(String gameId) async {
    await ready;
    final updated = _records
        .where((record) => record.gameId != gameId)
        .toList(growable: false);
    if (updated.length == _records.length) return false;

    final prefs = await SharedPreferences.getInstance();
    final persisted = await prefs.setStringList(
      _storageKey,
      updated.map((item) => jsonEncode(item.toJson())).toList(growable: false),
    );
    if (!persisted) return false;

    _records
      ..clear()
      ..addAll(updated);
    notifyListeners();
    return true;
  }

  @visibleForTesting
  static String get storageKey => _storageKey;
}
