import 'dart:convert';

import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable outbox for complete, validated game records.
///
/// Uploading is deliberately outside this service. Entries remain stored until
/// a future uploader explicitly acknowledges them.
class GameRecordUploadQueue extends ChangeNotifier {
  static const _storageKey = 'game_record_upload_queue_v1';

  final GameRecordValidator _validator;
  final List<GameRecord> _records = [];
  late final Future<void> ready;

  GameRecordUploadQueue(
      {GameRecordValidator validator = const GameRecordValidator()})
      : _validator = validator {
    ready = _load();
  }

  List<GameRecord> get records => List.unmodifiable(_records);

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
    notifyListeners();
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
