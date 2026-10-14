import 'package:blood_on_the_clocktower/models/game_record.dart';

/// Persisted, privacy-safe working state used while a game is running.
///
/// A capture may intentionally be incomplete (for example, a Traveller's
/// alignment is not currently known by the app). Only [GameRecord] instances
/// that pass the central validator are exposed as completed records.
class GameRecordCapture {
  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String gameId;
  final DateTime startedAt;
  final GameRecordScript script;
  final List<GameRecordCapturePlayer> players;
  final List<GameRecordCapturedPhase> phases;
  final DateTime? endedAt;
  final GameTeam? winnerTeam;

  GameRecordCapture({
    this.schemaVersion = currentSchemaVersion,
    required this.gameId,
    required this.startedAt,
    required this.script,
    required List<GameRecordCapturePlayer> players,
    required List<GameRecordCapturedPhase> phases,
    this.endedAt,
    this.winnerTeam,
  })  : players = List.unmodifiable(players),
        phases = List.unmodifiable(phases);

  GameRecordCapture copyWith({
    List<GameRecordCapturePlayer>? players,
    List<GameRecordCapturedPhase>? phases,
    DateTime? endedAt,
    GameTeam? winnerTeam,
  }) =>
      GameRecordCapture(
        schemaVersion: schemaVersion,
        gameId: gameId,
        startedAt: startedAt,
        script: script,
        players: players ?? this.players,
        phases: phases ?? this.phases,
        endedAt: endedAt ?? this.endedAt,
        winnerTeam: winnerTeam ?? this.winnerTeam,
      );

  factory GameRecordCapture.fromJson(Map<String, dynamic> json) {
    final players = json['players'];
    final phases = json['phases'];
    if (players is! List || phases is! List) {
      throw const FormatException('Capture players and phases are required.');
    }
    return GameRecordCapture(
      schemaVersion: json['schemaVersion'] as int? ?? 0,
      gameId: json['gameId'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      script: GameRecordScript.fromJson(
        Map<String, dynamic>.from(json['script'] as Map),
      ),
      players: players
          .whereType<Map>()
          .map((item) => GameRecordCapturePlayer.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      phases: phases
          .whereType<Map>()
          .map((item) => GameRecordCapturedPhase.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      endedAt: _optionalDateTime(json['endedAt']),
      winnerTeam: _optionalTeam(json['winnerTeam']),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'gameId': gameId,
        'startedAt': startedAt.toIso8601String(),
        'script': script.toJson(),
        'players': players.map((player) => player.toJson()).toList(),
        'phases': phases.map((phase) => phase.toJson()).toList(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (winnerTeam != null) 'winnerTeam': winnerTeam!.name,
      };
}

class GameRecordCapturePlayer {
  final String anonymizedPlayerId;
  final int position;
  final String initialCharacterInstanceId;
  final String currentCharacterInstanceId;
  final String? actualStartRoleId;
  final String displayedStartRoleId;
  final GameTeam? startTeam;
  final String currentRoleId;
  final GameTeam? currentTeam;

  const GameRecordCapturePlayer({
    required this.anonymizedPlayerId,
    required this.position,
    required this.initialCharacterInstanceId,
    required this.currentCharacterInstanceId,
    required this.actualStartRoleId,
    required this.displayedStartRoleId,
    required this.startTeam,
    required this.currentRoleId,
    required this.currentTeam,
  });

  GameRecordCapturePlayer copyWith({
    String? currentCharacterInstanceId,
    String? actualStartRoleId,
    GameTeam? startTeam,
    String? currentRoleId,
    GameTeam? currentTeam,
  }) =>
      GameRecordCapturePlayer(
        anonymizedPlayerId: anonymizedPlayerId,
        position: position,
        initialCharacterInstanceId: initialCharacterInstanceId,
        currentCharacterInstanceId:
            currentCharacterInstanceId ?? this.currentCharacterInstanceId,
        actualStartRoleId: actualStartRoleId ?? this.actualStartRoleId,
        displayedStartRoleId: displayedStartRoleId,
        startTeam: startTeam ?? this.startTeam,
        currentRoleId: currentRoleId ?? this.currentRoleId,
        currentTeam: currentTeam ?? this.currentTeam,
      );

  factory GameRecordCapturePlayer.fromJson(Map<String, dynamic> json) =>
      GameRecordCapturePlayer(
        anonymizedPlayerId: json['anonymizedPlayerId'] as String? ?? '',
        position: json['position'] as int? ?? -1,
        initialCharacterInstanceId:
            json['initialCharacterInstanceId'] as String? ?? '',
        currentCharacterInstanceId:
            json['currentCharacterInstanceId'] as String? ?? '',
        actualStartRoleId: json['actualStartRoleId'] as String?,
        displayedStartRoleId: json['displayedStartRoleId'] as String? ?? '',
        startTeam: _optionalTeam(json['startTeam']),
        currentRoleId: json['currentRoleId'] as String? ?? '',
        currentTeam: _optionalTeam(json['currentTeam']),
      );

  Map<String, dynamic> toJson() => {
        'anonymizedPlayerId': anonymizedPlayerId,
        'position': position,
        'initialCharacterInstanceId': initialCharacterInstanceId,
        'currentCharacterInstanceId': currentCharacterInstanceId,
        if (actualStartRoleId != null) 'actualStartRoleId': actualStartRoleId,
        'displayedStartRoleId': displayedStartRoleId,
        if (startTeam != null) 'startTeam': startTeam!.name,
        'currentRoleId': currentRoleId,
        if (currentTeam != null) 'currentTeam': currentTeam!.name,
      };
}

class GameRecordCapturedPhase {
  final String phaseId;
  final GameRecordPhaseType type;
  final int round;
  final DateTime startedAt;
  final DateTime? endedAt;

  const GameRecordCapturedPhase({
    required this.phaseId,
    required this.type,
    required this.round,
    required this.startedAt,
    this.endedAt,
  });

  bool get isOpen => endedAt == null;

  GameRecordCapturedPhase close(DateTime at) => GameRecordCapturedPhase(
        phaseId: phaseId,
        type: type,
        round: round,
        startedAt: startedAt,
        endedAt: at.isBefore(startedAt) ? startedAt : at,
      );

  GameRecordPhase? toGameRecordPhase() {
    final end = endedAt;
    if (end == null || !end.isAfter(startedAt)) return null;
    return GameRecordPhase(
      phaseId: phaseId,
      type: type,
      round: round,
      startedAt: startedAt,
      endedAt: end,
      duration: end.difference(startedAt),
    );
  }

  factory GameRecordCapturedPhase.fromJson(Map<String, dynamic> json) =>
      GameRecordCapturedPhase(
        phaseId: json['phaseId'] as String? ?? '',
        type: GameRecordPhaseType.values.firstWhere(
          (type) => type.name == json['type'],
          orElse: () => throw const FormatException('Unknown phase type.'),
        ),
        round: json['round'] as int? ?? 0,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: _optionalDateTime(json['endedAt']),
      );

  Map<String, dynamic> toJson() => {
        'phaseId': phaseId,
        'type': type.name,
        'round': round,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
      };
}

DateTime? _optionalDateTime(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

GameTeam? _optionalTeam(dynamic value) {
  if (value is! String) return null;
  return GameTeam.values.where((team) => team.name == value).firstOrNull;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
