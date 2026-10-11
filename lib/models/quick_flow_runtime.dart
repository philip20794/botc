import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';

class QuickFlowEntry {
  final Character owner;
  final QuickFlowPhase phase;
  final QuickFlowStep step;

  const QuickFlowEntry({
    required this.owner,
    required this.phase,
    required this.step,
  });

  String get key => '${owner.id}:${phase.name}:${step.id}';
}

class QuickFlowInfo {
  final String kind;
  final Character owner;
  final Character? sourceCharacter;
  final Character? selectedCharacter;
  final List<Character> players;

  const QuickFlowInfo({
    required this.kind,
    required this.owner,
    this.sourceCharacter,
    this.selectedCharacter,
    this.players = const [],
  });
}

class QuickFlowAssignmentResult {
  final bool handled;
  final bool success;
  final QuickFlowAssignmentFailure? failure;
  final QuickFlowAssignmentFailure? warning;

  const QuickFlowAssignmentResult._({
    required this.handled,
    required this.success,
    this.failure,
    this.warning,
  });

  const QuickFlowAssignmentResult.notHandled()
      : this._(handled: false, success: false);

  const QuickFlowAssignmentResult.success({QuickFlowAssignmentFailure? warning})
      : this._(handled: true, success: true, warning: warning);

  const QuickFlowAssignmentResult.failure(QuickFlowAssignmentFailure failure)
      : this._(handled: true, success: false, failure: failure);
}

enum QuickFlowAssignmentFailure {
  unsupported,
  invalidTarget,
  duplicateTarget,
  previousNightTarget,
}
