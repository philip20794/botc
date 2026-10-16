import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChronicleService extends ChangeNotifier {
  static const _activeKey = 'chronicle_active_v1';
  static const _lastKey = 'chronicle_last_v1';

  late final Future<void> ready;
  ChronicleLog? _active;
  ChronicleLog? _last;

  ChronicleService() {
    ready = _load();
  }

  ChronicleLog? get activeChronicle => _active;
  ChronicleLog? get lastChronicle => _last;
  bool get hasActiveChronicle => _active?.events.isNotEmpty == true;
  bool get hasLastChronicle => _last?.events.isNotEmpty == true;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _active = _decode(prefs.getString(_activeKey));
    _last = _decode(prefs.getString(_lastKey));
    final activeMigrated = _active != null && _migrateLegacyEvents(_active!);
    final lastMigrated = _last != null && _migrateLegacyEvents(_last!);
    if (activeMigrated) {
      await prefs.setString(_activeKey, jsonEncode(_active!.toJson()));
    }
    if (lastMigrated) {
      await prefs.setString(_lastKey, jsonEncode(_last!.toJson()));
    }
    notifyListeners();
  }

  ChronicleLog? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map
          ? ChronicleLog.fromJson(Map<String, dynamic>.from(value))
          : null;
    } catch (_) {
      return null;
    }
  }

  bool _migrateLegacyEvents(ChronicleLog log) {
    var changed = false;
    for (var index = 0; index < log.events.length; index++) {
      final event = log.events[index];
      if (event.type != ChronicleEventType.nightInformation ||
          event.inputDefinition != null) {
        continue;
      }
      final schema = ChronicleSchema.fromJson(event.details['schema']);
      final definitions = schema?.definitionsForNight(event.round) ?? const [];
      if (definitions.isEmpty) continue;
      final definition = definitions.first;
      final values = <String, dynamic>{};
      final fields = definition.type == ChronicleInputType.form
          ? definition.fields
          : [definition];
      for (final field in fields) {
        if (event.details.containsKey(field.id)) {
          values[field.id] = event.details[field.id];
        } else if (field.type == ChronicleInputType.number &&
            event.details['number'] != null) {
          values[field.id] = event.details['number'];
        } else if (field.type == ChronicleInputType.yesNo &&
            event.details['answer'] != null) {
          values[field.id] = event.details['answer'];
        } else if ((field.type == ChronicleInputType.player ||
                field.type == ChronicleInputType.players) &&
            event.targets.isNotEmpty) {
          values[field.id] = field.type == ChronicleInputType.player
              ? event.targets.first.toJson()
              : event.targets.map((target) => target.toJson()).toList();
        }
      }
      log.events[index] = event.copyWith(
        details: {
          'definition': definition.toJson(),
          'entries': event.hasInformation
              ? [
                  {
                    'entryId': 'legacy',
                    'values': values,
                    'targets':
                        event.targets.map((target) => target.toJson()).toList(),
                  },
                ]
              : <Map<String, dynamic>>[],
        },
      );
      changed = true;
    }
    return changed;
  }

  Future<void> startNewGame(
    List<Character> characters, {
    String? gameId,
    DateTime? startedAt,
  }) async {
    await ready;
    if (_active?.events.isNotEmpty == true) {
      await archiveCurrent();
    }
    final now = startedAt ?? DateTime.now();
    _active = ChronicleLog(
      gameId: gameId ?? _newGameId(now),
      startedAt: now,
      events: [
        ChronicleEvent(
          id: 'game-started',
          timestamp: now,
          type: ChronicleEventType.gameStarted,
          phase: ChroniclePhase.setup,
          round: 0,
          targets: characters
              .map(ChronicleCharacterSnapshot.fromCharacter)
              .toList(growable: false),
          details: {
            'chronicleSchemas': {
              for (final character in characters)
                if (character.chronicle != null)
                  character.id: character.chronicle!.toJson(),
            },
          },
        ),
      ],
    );
    await _persistActive();
    notifyListeners();
  }

  Future<ChronicleLog?> archiveCurrent({
    String? winningTeam,
    DateTime? endedAt,
  }) async {
    await ready;
    if (_active == null) return null;
    final immutableSnapshot = ChronicleLog.fromJson(_active!.toJson());
    _last = immutableSnapshot.copyWith(
      endedAt: endedAt ?? DateTime.now(),
      winningTeam: winningTeam,
    );
    _active = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_activeKey),
      prefs.setString(_lastKey, jsonEncode(_last!.toJson())),
    ]);
    notifyListeners();
    return ChronicleLog.fromJson(_last!.toJson());
  }

  Future<void> factoryReset() async {
    _active = null;
    _last = null;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_activeKey), prefs.remove(_lastKey)]);
    notifyListeners();
  }

  /// Saves an independently editable Savant statement in the current game.
  Future<String?> upsertSavantStatement({
    String? eventId,
    required int round,
    required ChronicleCharacterSnapshot actor,
    required Map<String, dynamic> statement,
  }) async {
    await ready;
    final active = _active;
    if (active == null || round < 1) return null;
    final events = List<ChronicleEvent>.from(active.events);
    final index = eventId == null
        ? -1
        : events.indexWhere((event) =>
            event.id == eventId &&
            event.type == ChronicleEventType.savantStatement &&
            event.round == round);
    final id = index >= 0 ? events[index].id : _uniqueId('savant:$round');
    final event = index >= 0
        ? events[index].copyWith(details: {'statement': statement})
        : ChronicleEvent(
            id: id,
            timestamp: DateTime.now(),
            type: ChronicleEventType.savantStatement,
            phase: ChroniclePhase.day,
            round: round,
            character: actor,
            details: {'statement': statement},
          );
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
    _active = active.copyWith(events: events);
    await _persistActive();
    notifyListeners();
    return id;
  }

  Future<void> removeSavantStatement(String eventId) async {
    await ready;
    final active = _active;
    if (active == null) return;
    final events = active.events.where((event) =>
        event.id != eventId ||
        event.type != ChronicleEventType.savantStatement).toList();
    if (events.length == active.events.length) return;
    _active = active.copyWith(events: events);
    await _persistActive();
    notifyListeners();
  }

  Future<void> recordPhase(ChroniclePhase phase, int round) async {
    if (!await _ensureActive()) return;
    final id = 'phase:${phase.name}:$round';
    if (_active!.events.any((event) => event.id == id)) return;
    await _append(ChronicleEvent(
      id: id,
      timestamp: DateTime.now(),
      type: ChronicleEventType.phaseStarted,
      phase: phase,
      round: round,
    ));
  }

  Future<void> recordNightVisit(Character character, int round) async {
    final schema = character.chronicle;
    if (schema == null || !await _ensureActive()) return;
    if (schema.recordsNightStep) {
      final visitId = 'night-visit:$round:${character.id}';
      if (!_active!.events.any((event) => event.id == visitId)) {
        await _append(ChronicleEvent(
          id: visitId,
          timestamp: DateTime.now(),
          type: ChronicleEventType.nightActionVisited,
          phase: ChroniclePhase.night,
          round: round,
          character: ChronicleCharacterSnapshot.fromCharacter(character),
        ));
      }
    }
    for (final definition in schema.definitionsForNight(round)) {
      if (!definition.onlyIfApplicable) {
        await _ensureInformationEvent(
          log: _active!,
          character: ChronicleCharacterSnapshot.fromCharacter(character),
          definition: definition,
          round: round,
          persistAsArchived: false,
        );
      }
    }
  }

  Future<void> hideSummary(String summaryId, {required bool archived}) async {
    final log = archived ? _last : _active;
    if (log == null || log.hiddenSummaryIds.contains(summaryId)) return;
    final hidden = [...log.hiddenSummaryIds, summaryId];
    if (archived) {
      _last = log.copyWith(hiddenSummaryIds: hidden);
    } else {
      _active = log.copyWith(hiddenSummaryIds: hidden);
    }
    await _persistLog(archived: archived);
    notifyListeners();
  }

  Future<void> restoreSummary(
    String summaryId, {
    required bool archived,
  }) async {
    final log = archived ? _last : _active;
    if (log == null || !log.hiddenSummaryIds.contains(summaryId)) return;
    final hidden = log.hiddenSummaryIds
        .where((id) => id != summaryId)
        .toList(growable: false);
    if (archived) {
      _last = log.copyWith(hiddenSummaryIds: hidden);
    } else {
      _active = log.copyWith(hiddenSummaryIds: hidden);
    }
    await _persistLog(archived: archived);
    notifyListeners();
  }

  Future<void> saveNightInformation({
    required String eventId,
    required Map<String, dynamic> value,
    List<Character> selectedPlayers = const [],
  }) async {
    final event =
        _active?.events.firstWhereOrNull((item) => item.id == eventId);
    if (event == null) return;
    if (event.details['definition'] != null) {
      await saveInformationEntry(
        eventId: eventId,
        values: value,
        targets: selectedPlayers
            .map(ChronicleCharacterSnapshot.fromCharacter)
            .toList(growable: false),
      );
      return;
    }
    final index = _active!.events.indexOf(event);
    _active!.events[index] = event.copyWith(
      timestamp: DateTime.now(),
      targets: selectedPlayers
          .map(ChronicleCharacterSnapshot.fromCharacter)
          .toList(growable: false),
      details: {...event.details, ...value, 'completed': true},
    );
    await _persistActive();
    notifyListeners();
  }

  Future<String?> saveInformationEntry({
    required String eventId,
    String? entryId,
    required Map<String, dynamic> values,
    List<ChronicleCharacterSnapshot> targets = const [],
    bool archived = false,
  }) async {
    final log = archived ? _last : _active;
    if (log == null) return null;
    final eventIndex = log.events.indexWhere((event) => event.id == eventId);
    if (eventIndex < 0 ||
        log.events[eventIndex].type != ChronicleEventType.nightInformation) {
      return null;
    }
    final event = log.events[eventIndex];
    final entries = event.informationEntries;
    final stableId = entryId ?? _newEntryId(entries);
    final entryIndex =
        entries.indexWhere((entry) => entry['entryId'] == stableId);
    final savedEntry = <String, dynamic>{
      'entryId': stableId,
      'values': values,
      'targets': targets.map((target) => target.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (entryIndex < 0) {
      entries.add(savedEntry);
    } else {
      entries[entryIndex] = savedEntry;
    }
    log.events[eventIndex] = event.copyWith(
      targets: _entryTargets(entries),
      details: {...event.details, 'entries': entries},
    );
    await _persistLog(archived: archived);
    notifyListeners();
    return stableId;
  }

  Future<void> deleteInformationEntry({
    required String eventId,
    required String entryId,
    bool archived = false,
  }) async {
    final log = archived ? _last : _active;
    if (log == null) return;
    final eventIndex = log.events.indexWhere((event) => event.id == eventId);
    if (eventIndex < 0) return;
    final event = log.events[eventIndex];
    final entries = event.informationEntries
      ..removeWhere((entry) => entry['entryId'] == entryId);
    log.events[eventIndex] = event.copyWith(
      targets: _entryTargets(entries),
      details: {...event.details, 'entries': entries},
    );
    await _persistLog(archived: archived);
    notifyListeners();
  }

  Future<ChronicleEvent?> addOptionalInformation({
    required ChronicleCharacterSnapshot character,
    required ChronicleInputDefinition definition,
    required int round,
    bool archived = false,
  }) async {
    final log = archived ? _last : _active;
    if (log == null || !definition.appliesToNight(round)) return null;
    return _ensureInformationEvent(
      log: log,
      character: character,
      definition: definition,
      round: round,
      persistAsArchived: archived,
    );
  }

  List<ChronicleOptionalDefinition> optionalDefinitions({
    required int round,
    required List<Character> catalog,
    bool archived = false,
  }) {
    final log = archived ? _last : _active;
    if (log == null || round < 1) return const [];
    final started = log.events.firstWhereOrNull(
      (event) => event.type == ChronicleEventType.gameStarted,
    );
    if (started == null) return const [];
    final schemas = started.details['chronicleSchemas'] is Map
        ? Map<String, dynamic>.from(
            started.details['chronicleSchemas'] as Map,
          )
        : const <String, dynamic>{};
    final result = <ChronicleOptionalDefinition>[];
    final roster = [...started.targets];
    for (final event in log.events.where(
      (event) =>
          event.type == ChronicleEventType.characterChanged &&
          event.round <= round &&
          event.character != null &&
          event.targets.isNotEmpty,
    )) {
      final index = roster.indexWhere(
        (snapshot) =>
            snapshot.characterId == event.character!.characterId ||
            (snapshot.playerName.isNotEmpty &&
                snapshot.playerName == event.character!.playerName),
      );
      if (index >= 0) roster[index] = event.targets.first;
    }
    for (final snapshot in roster) {
      final fallback = catalog.firstWhereOrNull(
        (character) => character.roleId == snapshot.roleId,
      );
      final schema = ChronicleSchema.fromJson(schemas[snapshot.characterId]) ??
          fallback?.chronicle;
      if (schema == null) continue;
      for (final definition in schema.definitionsForNight(round)) {
        if (!definition.onlyIfApplicable) continue;
        final existing = _informationEvent(
          log,
          snapshot.characterId,
          definition.id,
          round,
        );
        if (existing == null || definition.repeatable) {
          result.add(ChronicleOptionalDefinition(
            character: snapshot,
            definition: definition,
          ));
        }
      }
    }
    return result;
  }

  Future<void> recordLifeStatus({
    required Character character,
    required bool alive,
    required ChroniclePhase phase,
    required int round,
  }) async {
    if (!await _ensureActive()) return;
    await _append(ChronicleEvent(
      id: _uniqueId('life:${character.id}'),
      timestamp: DateTime.now(),
      type: ChronicleEventType.lifeStatusChanged,
      phase: phase,
      round: round,
      character: ChronicleCharacterSnapshot.fromCharacter(character),
      details: {'alive': alive},
    ));
  }

  Future<void> recordReminderAssignment({
    required Character target,
    Character? previousTarget,
    required Token token,
    required ChroniclePhase phase,
    required int round,
    String source = 'manual',
    String? quickFlowStepId,
    Character? quickFlowOwner,
  }) async {
    if (source == 'quickFlow' &&
        quickFlowOwner?.chronicle?.recordsQuickFlow != true) {
      return;
    }
    if (!await _ensureActive()) return;
    await _append(ChronicleEvent(
      id: _uniqueId(
          'reminder:${token.ownerRoleInstanceId}:${token.quickId ?? token.name}'),
      timestamp: DateTime.now(),
      type: ChronicleEventType.reminderAssigned,
      phase: phase,
      round: round,
      character: ChronicleCharacterSnapshot.fromCharacter(target),
      targets: previousTarget == null
          ? const []
          : [ChronicleCharacterSnapshot.fromCharacter(previousTarget)],
      details: {
        'tokenName': token.name,
        'tokenImage': token.image,
        'quickId': token.quickId,
        'ownerRoleInstanceId': token.ownerRoleInstanceId,
        'source': source,
        if (quickFlowStepId != null) 'quickFlowStepId': quickFlowStepId,
        if (quickFlowOwner != null)
          'quickFlowOwner':
              ChronicleCharacterSnapshot.fromCharacter(quickFlowOwner).toJson(),
      },
    ));
  }

  /// Captures the target(s) that a recurring QuickFlow reminder has when its
  /// owner's night step is completed. This is intentionally separate from a
  /// token-movement event: a token may stay on the same player all night.
  Future<void> recordQuickFlowReminderSnapshot({
    required Character owner,
    required String stepId,
    required Token token,
    required List<Character> targets,
    required int round,
  }) async {
    if (owner.chronicle?.recordsQuickFlow != true || !await _ensureActive()) {
      return;
    }
    final active = _active!;
    // A log restored by an older app version can still hold a fixed-length
    // event list in a running isolate. Never mutate that list in place while
    // replacing a snapshot at the night-to-day boundary.
    final events = List<ChronicleEvent>.from(active.events);
    final matchingIndexes = <int>[];
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      if (event.type == ChronicleEventType.reminderAssigned &&
          event.phase == ChroniclePhase.night &&
          event.round == round &&
          event.details['snapshot'] == true &&
          event.details['quickFlowStepId'] == stepId &&
          event.details['quickFlowOwner'] is Map &&
          (event.details['quickFlowOwner'] as Map)['characterId'] == owner.id) {
        matchingIndexes.add(index);
      }
    }
    for (final index in matchingIndexes.reversed) {
      events.removeAt(index);
    }
    if (targets.isEmpty) {
      if (matchingIndexes.isNotEmpty) {
        _active = active.copyWith(events: events);
        await _persistActive();
        notifyListeners();
      }
      return;
    }
    final timestamp = DateTime.now();
    for (final target in targets) {
      events.add(ChronicleEvent(
        id: 'quick-reminder-snapshot:$round:${owner.id}:$stepId:${target.id}',
        timestamp: timestamp,
        type: ChronicleEventType.reminderAssigned,
        phase: ChroniclePhase.night,
        round: round,
        character: ChronicleCharacterSnapshot.fromCharacter(target),
        details: {
          'tokenName': token.name,
          'tokenImage': token.image,
          'quickId': token.quickId,
          'ownerRoleInstanceId': token.ownerRoleInstanceId,
          'source': 'quickFlow',
          'snapshot': true,
          'quickFlowStepId': stepId,
          'quickFlowOwner':
              ChronicleCharacterSnapshot.fromCharacter(owner).toJson(),
        },
      ));
    }
    _active = active.copyWith(events: events);
    await _persistActive();
    notifyListeners();
  }

  Future<void> recordReminderRemoval({
    required Character target,
    required Token token,
    required ChroniclePhase phase,
    required int round,
  }) async {
    if (!await _ensureActive()) return;
    await _append(ChronicleEvent(
      id: _uniqueId('reminder-removed:${target.id}'),
      timestamp: DateTime.now(),
      type: ChronicleEventType.reminderRemoved,
      phase: phase,
      round: round,
      character: ChronicleCharacterSnapshot.fromCharacter(target),
      details: {
        'tokenName': token.name,
        'tokenImage': token.image,
        'quickId': token.quickId,
        'ownerRoleInstanceId': token.ownerRoleInstanceId,
      },
    ));
  }

  Future<void> recordQuickFlowCharacterSelection({
    required Character owner,
    required Character selected,
    required String stepId,
    required ChroniclePhase phase,
    required int round,
  }) async {
    if (owner.chronicle?.recordsQuickFlow != true) return;
    if (!await _ensureActive()) return;
    await _append(ChronicleEvent(
      id: _uniqueId('quick-character:$stepId'),
      timestamp: DateTime.now(),
      type: ChronicleEventType.quickFlowCharacterSelected,
      phase: phase,
      round: round,
      character: ChronicleCharacterSnapshot.fromCharacter(owner),
      targets: [ChronicleCharacterSnapshot.fromCharacter(selected)],
      details: {'stepId': stepId},
    ));
  }

  Future<void> recordQuickFlowInfo({
    required Character owner,
    required String stepId,
    required ChroniclePhase phase,
    required int round,
  }) async {
    if (owner.chronicle?.recordsQuickFlow != true) return;
    if (!await _ensureActive()) return;
    await _append(ChronicleEvent(
      id: _uniqueId('quick-info:$stepId'),
      timestamp: DateTime.now(),
      type: ChronicleEventType.quickFlowInfoConfirmed,
      phase: phase,
      round: round,
      character: ChronicleCharacterSnapshot.fromCharacter(owner),
      details: {'stepId': stepId},
    ));
  }

  Future<void> recordCharacterChange({
    required Character oldCharacter,
    required Character newCharacter,
    DateTime? occurredAt,
  }) async {
    if (_active == null) return;
    final latest = _active!.events.lastOrNull;
    await _append(ChronicleEvent(
      id: _uniqueId('character-change:${oldCharacter.id}'),
      timestamp: occurredAt ?? DateTime.now(),
      type: ChronicleEventType.characterChanged,
      phase: latest?.phase ?? ChroniclePhase.setup,
      round: latest?.round ?? 0,
      character: ChronicleCharacterSnapshot.fromCharacter(oldCharacter),
      targets: [ChronicleCharacterSnapshot.fromCharacter(newCharacter)],
    ));
  }

  Future<ChronicleEvent> _ensureInformationEvent({
    required ChronicleLog log,
    required ChronicleCharacterSnapshot character,
    required ChronicleInputDefinition definition,
    required int round,
    required bool persistAsArchived,
  }) async {
    final existing = _informationEvent(
      log,
      character.characterId,
      definition.id,
      round,
    );
    if (existing != null) return existing;
    final event = ChronicleEvent(
      id: 'night-info:$round:${character.characterId}:${definition.id}',
      timestamp: DateTime.now(),
      type: ChronicleEventType.nightInformation,
      phase: ChroniclePhase.night,
      round: round,
      character: character,
      details: {
        'definition': definition.toJson(),
        'entries': <Map<String, dynamic>>[],
      },
    );
    log.events.add(event);
    await _persistLog(archived: persistAsArchived);
    notifyListeners();
    return event;
  }

  ChronicleEvent? _informationEvent(
    ChronicleLog log,
    String characterId,
    String definitionId,
    int round,
  ) =>
      log.events.firstWhereOrNull(
        (event) =>
            event.type == ChronicleEventType.nightInformation &&
            event.round == round &&
            event.character?.characterId == characterId &&
            event.inputDefinition?.id == definitionId,
      );

  String _newEntryId(List<Map<String, dynamic>> entries) {
    final base = DateTime.now().microsecondsSinceEpoch.toString();
    final used = entries.map((entry) => entry['entryId']).toSet();
    if (!used.contains(base)) return base;
    var suffix = 1;
    while (used.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  List<ChronicleCharacterSnapshot> _entryTargets(
    List<Map<String, dynamic>> entries,
  ) {
    final result = <ChronicleCharacterSnapshot>[];
    for (final entry in entries) {
      final targets = entry['targets'];
      if (targets is! List) continue;
      for (final raw in targets.whereType<Map>()) {
        final snapshot = ChronicleCharacterSnapshot.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (!result.any(
          (target) => target.characterId == snapshot.characterId,
        )) {
          result.add(snapshot);
        }
      }
    }
    return result;
  }

  Future<bool> _ensureActive() async {
    await ready;
    if (_active != null) return true;
    final now = DateTime.now();
    _active = ChronicleLog(
      gameId: _newGameId(now),
      startedAt: now,
      events: [],
    );
    await _persistActive();
    return true;
  }

  String _uniqueId(String prefix) =>
      '$prefix:${DateTime.now().microsecondsSinceEpoch}';

  String _newGameId(DateTime now) {
    final base = now.microsecondsSinceEpoch.toString();
    final usedIds = {_active?.gameId, _last?.gameId};
    if (!usedIds.contains(base)) return base;
    var suffix = 1;
    while (usedIds.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  Future<void> _append(ChronicleEvent event) async {
    _active!.events.add(event);
    await _persistActive();
    notifyListeners();
  }

  Future<void> _persistActive() async {
    final prefs = await SharedPreferences.getInstance();
    if (_active == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, jsonEncode(_active!.toJson()));
    }
  }

  Future<void> _persistLog({required bool archived}) async {
    final prefs = await SharedPreferences.getInstance();
    final log = archived ? _last : _active;
    final key = archived ? _lastKey : _activeKey;
    if (log == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(log.toJson()));
    }
  }
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;

  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
