import 'package:blood_on_the_clocktower/models/chronicle.dart';

/// Read-only projection of all technical events belonging to one visited
/// character step in one night.
class ChronicleSummaryEntry {
  final String id;
  final ChroniclePhase phase;
  final int round;
  final ChronicleCharacterSnapshot actor;
  final DateTime timestamp;
  final List<ChronicleEvent> events;

  const ChronicleSummaryEntry({
    required this.id,
    required this.phase,
    required this.round,
    required this.actor,
    required this.timestamp,
    required this.events,
  });
}

class ChronicleSummaryProjector {
  const ChronicleSummaryProjector();

  List<ChronicleSummaryEntry> project(List<ChronicleEvent> rawEvents) {
    final ordered = [...rawEvents]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final groups = <String, _SummaryAccumulator>{};

    for (final event in ordered) {
      if (event.type == ChronicleEventType.lifeStatusChanged &&
          event.character != null &&
          event.round >= 1) {
        final id = 'life:${event.id}';
        groups[id] = _SummaryAccumulator(
          id: id,
          phase: event.phase,
          round: event.round,
          actor: event.character!,
          timestamp: event.timestamp,
        )..events.add(event);
        continue;
      }
      if (event.phase != ChroniclePhase.night || event.round < 1) continue;
      final actor = _actorOf(event);
      if (actor == null || !_belongsToNightSummary(event)) continue;
      final id = '${event.phase.name}:${event.round}:${actor.characterId}';
      groups
          .putIfAbsent(
            id,
            () => _SummaryAccumulator(
              id: id,
              phase: event.phase,
              round: event.round,
              actor: actor,
              timestamp: event.timestamp,
            ),
          )
          .events
          .add(event);
    }

    return groups.values
        .map(
          (group) => ChronicleSummaryEntry(
            id: group.id,
            phase: group.phase,
            round: group.round,
            actor: group.actor,
            timestamp: group.timestamp,
            events: List.unmodifiable(group.events),
          ),
        )
        .toList(growable: false);
  }

  bool _belongsToNightSummary(ChronicleEvent event) => switch (event.type) {
        ChronicleEventType.nightActionVisited ||
        ChronicleEventType.nightInformation ||
        ChronicleEventType.quickFlowCharacterSelected ||
        ChronicleEventType.quickFlowInfoConfirmed =>
          true,
        ChronicleEventType.reminderAssigned =>
          event.details['source'] == 'quickFlow',
        _ => false,
      };

  ChronicleCharacterSnapshot? _actorOf(ChronicleEvent event) {
    if (event.type != ChronicleEventType.reminderAssigned) {
      return event.character;
    }
    final rawOwner = event.details['quickFlowOwner'];
    return rawOwner is Map
        ? ChronicleCharacterSnapshot.fromJson(
            Map<String, dynamic>.from(rawOwner),
          )
        : null;
  }
}

class _SummaryAccumulator {
  final String id;
  final ChroniclePhase phase;
  final int round;
  final ChronicleCharacterSnapshot actor;
  final DateTime timestamp;
  final List<ChronicleEvent> events = [];

  _SummaryAccumulator({
    required this.id,
    required this.phase,
    required this.round,
    required this.actor,
    required this.timestamp,
  });
}
