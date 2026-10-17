import 'package:blood_on_the_clocktower/models/game_record.dart';

class GameRecordValidationIssue {
  final String path;
  final String message;

  const GameRecordValidationIssue(this.path, this.message);
}

class GameRecordValidationResult {
  final List<GameRecordValidationIssue> issues;

  const GameRecordValidationResult(this.issues);

  bool get isValid => issues.isEmpty;
}

/// Single validation boundary for public game-statistics records.
class GameRecordValidator {
  static final _opaqueIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{7,127}$');
  static final _scriptIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_:-]{2,127}$');
  static final _roleOrTokenIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,127}$');
  static final _dataKeyPattern = RegExp(r'^[a-z][A-Za-z0-9_]{0,63}$');
  static final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

  const GameRecordValidator();

  GameRecordValidationResult validate(GameRecord record) {
    final issues = <GameRecordValidationIssue>[];
    void add(String path, String message) =>
        issues.add(GameRecordValidationIssue(path, message));

    if (record.schemaVersion != GameRecord.currentSchemaVersion) {
      add('schemaVersion', 'Unsupported schema version.');
    }
    if (!_opaqueIdPattern.hasMatch(record.gameId)) {
      add('gameId', 'Must be an opaque identifier.');
    }
    if (!record.endedAt.isAfter(record.startedAt)) {
      add('endedAt', 'Must be after startedAt.');
    }
    if (record.totalDuration.isNegative ||
        record.totalDuration != record.endedAt.difference(record.startedAt)) {
      add('totalDurationMs', 'Must exactly match the game timestamps.');
    }
    // Mirror the hard Firestore Rules limits before attempting any network
    // write. An otherwise locally valid record must not become a 403 upload.
    if (record.playerCount > 20) {
      add('playerCount', 'Firestore permits at most 20 player seats.');
    }
    if (record.phases.length > 512) {
      add('phases', 'Firestore permits at most 512 phases.');
    }
    if (record.chronicleEvents.length > 4096) {
      add('chronicleEvents', 'Firestore permits at most 4096 events.');
    }
    _validateScript(record.script, add);
    _validatePlayers(record, add);
    _validatePhases(record, add);
    _validateChronicleEvents(record, add);
    return GameRecordValidationResult(List.unmodifiable(issues));
  }

  void validateOrThrow(GameRecord record) {
    final result = validate(record);
    if (result.isValid) return;
    final details = result.issues
        .map((issue) => '${issue.path}: ${issue.message}')
        .join('; ');
    throw FormatException('Invalid GameRecord: $details');
  }

  void _validateScript(
    GameRecordScript script,
    void Function(String path, String message) add,
  ) {
    if (!_scriptIdPattern.hasMatch(script.scriptId)) {
      add('script.scriptId', 'Must be a stable script identifier.');
    }
    if (script.name.trim().isEmpty) add('script.name', 'Must not be empty.');
    if (script.name.length > 128) {
      add('script.name', 'Firestore permits at most 128 characters.');
    }
    if (script.roleIds.length > 512) {
      add('script.roleIds', 'Firestore permits at most 512 roles.');
    }
    if (script.roleIds.isEmpty) {
      add('script.roleIds', 'A complete game needs a non-empty role list.');
    }
    if (script.roleIds.toSet().length != script.roleIds.length) {
      add('script.roleIds', 'Role identifiers must be unique.');
    }
    for (final roleId in script.roleIds) {
      if (!_roleOrTokenIdPattern.hasMatch(roleId)) {
        add('script.roleIds', 'Contains an invalid role identifier.');
      }
    }
    if (!_sha256Pattern.hasMatch(script.contentHash) ||
        script.contentHash !=
            GameRecordScript.contentHashForRoleIds(script.roleIds)) {
      add('script.contentHash', 'Does not match the ordered role list.');
    }
  }

  void _validatePlayers(
    GameRecord record,
    void Function(String path, String message) add,
  ) {
    if (record.playerCount <= 0 ||
        record.playerCount != record.players.length) {
      add('playerCount', 'Must equal the number of anonymised players.');
    }
    final ids = <String>{};
    final positions = <int>{};
    for (var index = 0; index < record.players.length; index++) {
      final player = record.players[index];
      final path = 'players[$index]';
      if (!_opaqueIdPattern.hasMatch(player.anonymizedPlayerId) ||
          !ids.add(player.anonymizedPlayerId)) {
        add('$path.anonymizedPlayerId', 'Must be a unique opaque identifier.');
      }
      if (player.position < 0 || !positions.add(player.position)) {
        add('$path.position', 'Must be a unique non-negative position.');
      }
      for (final roleId in [
        player.actualStartRoleId,
        player.displayedStartRoleId,
        player.endRoleId,
      ]) {
        if (!_roleOrTokenIdPattern.hasMatch(roleId)) {
          add('$path.roleId', 'Contains an invalid role identifier.');
        }
      }
    }
    if (positions.length == record.players.length &&
        !positions
            .containsAll(List.generate(record.players.length, (i) => i))) {
      add('players.position', 'Positions must be contiguous from zero.');
    }
  }

  void _validatePhases(
    GameRecord record,
    void Function(String path, String message) add,
  ) {
    if (record.phases.isEmpty) {
      add('phases', 'A complete game needs at least one day or night phase.');
      return;
    }
    final ids = <String>{};
    final phaseKeys = <String>{};
    GameRecordPhase? previous;
    for (var index = 0; index < record.phases.length; index++) {
      final phase = record.phases[index];
      final path = 'phases[$index]';
      if (!_opaqueIdPattern.hasMatch(phase.phaseId) ||
          !ids.add(phase.phaseId)) {
        add('$path.phaseId', 'Must be a unique opaque identifier.');
      }
      if (phase.round < 1) add('$path.round', 'Must be at least one.');
      if (!phase.endedAt.isAfter(phase.startedAt) ||
          phase.duration.isNegative ||
          phase.duration != phase.endedAt.difference(phase.startedAt)) {
        add('$path.durationMs', 'Must exactly match its timestamps.');
      }
      if (phase.startedAt.isBefore(record.startedAt) ||
          phase.endedAt.isAfter(record.endedAt)) {
        add(path, 'Must be within the game timestamps.');
      }
      if (!phaseKeys.add('${phase.type.name}:${phase.round}')) {
        add(path, 'Duplicate day/night round.');
      }
      if (previous != null) {
        if (phase.startedAt.isBefore(previous.endedAt)) {
          add(path, 'Must not overlap the previous phase.');
        }
        if (phase.type == previous.type) {
          add(path, 'Day and night phases must alternate.');
        }
      }
      previous = phase;
    }
  }

  void _validateChronicleEvents(
    GameRecord record,
    void Function(String path, String message) add,
  ) {
    final playerIds =
        record.players.map((player) => player.anonymizedPlayerId).toSet();
    final phaseKeys = record.phases
        .map((phase) => '${phase.type.name}:${phase.round}')
        .toSet();
    final eventIds = <String>{};
    for (var index = 0; index < record.chronicleEvents.length; index++) {
      final event = record.chronicleEvents[index];
      final path = 'chronicleEvents[$index]';
      if (!_opaqueIdPattern.hasMatch(event.eventId) ||
          !eventIds.add(event.eventId)) {
        add('$path.eventId', 'Must be a unique opaque identifier.');
      }
      if (event.occurredAt.isBefore(record.startedAt) ||
          event.occurredAt.isAfter(record.endedAt)) {
        add('$path.occurredAt', 'Must be within the game timestamps.');
      }
      if (event.phase == GameRecordEventPhase.setup) {
        if (event.round != 0) {
          add('$path.round', 'Setup events require round zero.');
        }
      } else {
        if (event.round < 1 ||
            !phaseKeys.contains('${event.phase.name}:${event.round}')) {
          add('$path.phase', 'Must refer to a recorded day or night phase.');
        }
      }
      if (event.actorPlayerId != null &&
          !playerIds.contains(event.actorPlayerId)) {
        add('$path.actorPlayerId', 'Must refer to an anonymised player.');
      }
      if (event.targetPlayerIds.toSet().length !=
              event.targetPlayerIds.length ||
          event.targetPlayerIds.any((id) => !playerIds.contains(id))) {
        add('$path.targetPlayerIds', 'Must contain unique anonymised players.');
      }
      _validateEventData(event.data, path, playerIds, add);
    }
  }

  void _validateEventData(
    GameRecordEventData data,
    String path,
    Set<String> playerIds,
    void Function(String path, String message) add,
  ) {
    void validateKeys(Iterable<String> keys, String field) {
      if (keys.any((key) => !_dataKeyPattern.hasMatch(key))) {
        add('$path.$field', 'Contains an invalid structured-data key.');
      }
    }

    validateKeys(data.flags.keys, 'data.flags');
    validateKeys(data.numbers.keys, 'data.numbers');
    for (final entry in [
      MapEntry('roleIds', data.roleIds),
      MapEntry('playerIds', data.playerIds),
      MapEntry('tokenIds', data.tokenIds),
    ]) {
      validateKeys(entry.value.keys, 'data.${entry.key}');
      for (final values in entry.value.values) {
        if (values.isEmpty || values.toSet().length != values.length) {
          add('$path.data.${entry.key}', 'Lists must be non-empty and unique.');
        }
      }
    }
    if (data.roleIds.values
        .expand((values) => values)
        .any((id) => !_roleOrTokenIdPattern.hasMatch(id))) {
      add('$path.data.roleIds', 'Contains an invalid role identifier.');
    }
    if (data.tokenIds.values
        .expand((values) => values)
        .any((id) => !_roleOrTokenIdPattern.hasMatch(id))) {
      add('$path.data.tokenIds', 'Contains an invalid token identifier.');
    }
    if (data.playerIds.values
        .expand((values) => values)
        .any((id) => !playerIds.contains(id))) {
      add('$path.data.playerIds', 'Must refer to anonymised players.');
    }
  }
}
