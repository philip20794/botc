import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/token.dart';

class QuickFlowInterpreter {
  const QuickFlowInterpreter();

  static const supportedPresentationKinds = {
    'playersAndCharacter',
    'playerAndCharacter',
    'pointToPlayers',
    'showCharacter',
    'youAre',
    'characterSelectedYou',
    'characterSelectedYouMadAboutCharacter',
    'characterSelectedYouMadAboutPlayer',
  };

  bool isStepSupported(QuickFlowStep step, {Token? token}) {
    switch (step.type) {
      case QuickFlowStepType.reminder:
        if (token == null) return false;
        if (step.operation == QuickFlowReminderOperation.append &&
            !token.unlimited) {
          return false;
        }
        return step.nightConstraint == null ||
            step.nightConstraint == 'differentFromPreviousNight';
      case QuickFlowStepType.reminderCharacterToken:
        return step.selection != null;
      case QuickFlowStepType.showInfo:
        final presentation = step.presentation;
        if (presentation == null ||
            !supportedPresentationKinds.contains(presentation.kind)) {
          return false;
        }
        final visibility = step.showOnlyWhen;
        return visibility == null || visibility.type == 'storytellerConfirmed';
    }
  }

  bool matchesStaticTargetRules(
    QuickFlowStep step,
    Character owner,
    Character target, {
    required bool targetIsAlive,
  }) {
    final rules = step.allowedTargets;
    if (rules.fractions.isNotEmpty &&
        !rules.fractions.contains(target.fraction.name)) {
      return false;
    }
    if (rules.excludeFractions.contains(target.fraction.name)) return false;
    if (rules.roles.isNotEmpty && !rules.roles.contains(target.roleId)) {
      return false;
    }
    if (rules.alignment.isNotEmpty &&
        !rules.alignment.any((value) => _matchesAlignment(target, value))) {
      return false;
    }
    if (rules.excludeAbilityOwner && target.id == owner.id) return false;
    if (rules.aliveOnly && !targetIsAlive) return false;
    return true;
  }

  bool isCharacterAllowed(QuickFlowStep step, Character character) =>
      step.allowedFractions.isEmpty ||
      step.allowedFractions.contains(character.fraction.name);

  bool _matchesAlignment(Character target, String alignment) =>
      switch (alignment) {
        'good' => target.fraction == Fraction.townsfolk ||
            target.fraction == Fraction.outsider,
        'evil' => target.fraction == Fraction.minion ||
            target.fraction == Fraction.demon,
        _ => false,
      };
}
