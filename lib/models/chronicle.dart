import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';

enum ChroniclePhase { setup, night, day }

enum ChronicleEventType {
  gameStarted,
  phaseStarted,
  lifeStatusChanged,
  reminderAssigned,
  reminderRemoved,
  quickFlowCharacterSelected,
  quickFlowInfoConfirmed,
  characterChanged,
  nightActionVisited,
  nightInformation,
}

class ChronicleCharacterSnapshot {
  final String characterId;
  final String roleId;
  final String roleName;
  final String playerName;
  final String image;

  const ChronicleCharacterSnapshot({
    required this.characterId,
    required this.roleId,
    required this.roleName,
    required this.playerName,
    required this.image,
  });

  factory ChronicleCharacterSnapshot.fromCharacter(Character character) =>
      ChronicleCharacterSnapshot(
        characterId: character.id,
        roleId: character.roleId,
        roleName: character.name,
        playerName: character.playerName,
        image: character.image,
      );

  factory ChronicleCharacterSnapshot.fromJson(Map<String, dynamic> json) =>
      ChronicleCharacterSnapshot(
        characterId: json['characterId'] as String? ?? '',
        roleId: json['roleId'] as String? ?? '',
        roleName: json['roleName'] as String? ?? '',
        playerName: json['playerName'] as String? ?? '',
        image: json['image'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'roleId': roleId,
        'roleName': roleName,
        'playerName': playerName,
        'image': image,
      };
}

class ChronicleEvent {
  final String id;
  final DateTime timestamp;
  final ChronicleEventType type;
  final ChroniclePhase phase;
  final int round;
  final ChronicleCharacterSnapshot? character;
  final List<ChronicleCharacterSnapshot> targets;
  final Map<String, dynamic> details;

  const ChronicleEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.phase,
    required this.round,
    this.character,
    this.targets = const [],
    this.details = const {},
  });

  bool get hasInformation =>
      details['completed'] == true || informationEntries.isNotEmpty;

  ChronicleInputDefinition? get inputDefinition =>
      ChronicleInputDefinition.fromJson(details['definition']);

  List<Map<String, dynamic>> get informationEntries =>
      (details['entries'] is List ? details['entries'] as List : const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();

  ChronicleEvent copyWith({
    DateTime? timestamp,
    List<ChronicleCharacterSnapshot>? targets,
    Map<String, dynamic>? details,
  }) =>
      ChronicleEvent(
        id: id,
        timestamp: timestamp ?? this.timestamp,
        type: type,
        phase: phase,
        round: round,
        character: character,
        targets: targets ?? this.targets,
        details: details ?? this.details,
      );

  factory ChronicleEvent.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final phaseName = json['phase'] as String?;
    return ChronicleEvent(
      id: json['id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      type: ChronicleEventType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => ChronicleEventType.phaseStarted,
      ),
      phase: ChroniclePhase.values.firstWhere(
        (value) => value.name == phaseName,
        orElse: () => ChroniclePhase.setup,
      ),
      round: (json['round'] as num?)?.toInt() ?? 0,
      character: json['character'] is Map
          ? ChronicleCharacterSnapshot.fromJson(
              Map<String, dynamic>.from(json['character'] as Map),
            )
          : null,
      targets: (json['targets'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => ChronicleCharacterSnapshot.fromJson(
                Map<String, dynamic>.from(value),
              ))
          .toList(growable: false),
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'phase': phase.name,
        'round': round,
        if (character != null) 'character': character!.toJson(),
        'targets': targets.map((target) => target.toJson()).toList(),
        'details': details,
      };
}

class ChronicleOptionalDefinition {
  final ChronicleCharacterSnapshot character;
  final ChronicleInputDefinition definition;

  const ChronicleOptionalDefinition({
    required this.character,
    required this.definition,
  });
}

class ChronicleLog {
  final String gameId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ChronicleEvent> events;
  final List<String> hiddenSummaryIds;

  ChronicleLog({
    required this.gameId,
    required this.startedAt,
    required List<ChronicleEvent> events,
    this.endedAt,
    List<String> hiddenSummaryIds = const [],
  })  : events = List<ChronicleEvent>.from(events),
        hiddenSummaryIds = List<String>.from(hiddenSummaryIds);

  ChronicleLog copyWith({
    DateTime? endedAt,
    List<ChronicleEvent>? events,
    List<String>? hiddenSummaryIds,
  }) =>
      ChronicleLog(
        gameId: gameId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        events: events ?? this.events,
        hiddenSummaryIds: hiddenSummaryIds ?? this.hiddenSummaryIds,
      );

  factory ChronicleLog.fromJson(Map<String, dynamic> json) => ChronicleLog(
        gameId: json['gameId'] as String? ?? '',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endedAt: DateTime.tryParse(json['endedAt'] as String? ?? ''),
        events: (json['events'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((event) => ChronicleEvent.fromJson(
                  Map<String, dynamic>.from(event),
                ))
            .toList(),
        hiddenSummaryIds:
            (json['hiddenSummaryIds'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'events': events.map((event) => event.toJson()).toList(),
        if (hiddenSummaryIds.isNotEmpty) 'hiddenSummaryIds': hiddenSummaryIds,
      };
}
