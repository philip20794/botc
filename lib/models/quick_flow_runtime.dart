import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';
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
  final Character? recipient;
  final Character? sourceCharacter;
  final Character? selectedCharacter;
  final List<Character> selectedCharacters;
  final List<Character> players;
  final Basictoken? infoToken;

  const QuickFlowInfo({
    required this.kind,
    required this.owner,
    this.recipient,
    this.sourceCharacter,
    this.selectedCharacter,
    this.selectedCharacters = const [],
    this.players = const [],
    this.infoToken,
  });

  /// All character tokens that belong to this single prepared display.
  ///
  /// [selectedCharacter] is retained for persisted/older callers which only
  /// provide one token. New presentations may use [selectedCharacters].
  List<Character> get characters {
    final result = <Character>[];
    if (selectedCharacter != null) result.add(selectedCharacter!);
    for (final character in selectedCharacters) {
      if (!result.any((item) => item.roleId == character.roleId)) {
        result.add(character);
      }
    }
    return result;
  }
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
