import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/services/quick_flow_interpreter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('English catalog QuickFlow references are generic and resolvable',
      () async {
    final rawRoles = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final configuredRaw =
        rawRoles.where((role) => role['quickFlow'] is Map).toList();
    expect(configuredRaw, isNotEmpty);

    const interpreter = QuickFlowInterpreter();
    for (final raw in configuredRaw) {
      final character = Character.fromJson(raw);
      for (final phase in QuickFlowPhase.values) {
        final rawSectionName = switch (phase) {
          QuickFlowPhase.setup => 'setup',
          QuickFlowPhase.firstNight => 'firstNight',
          QuickFlowPhase.otherNights => 'otherNights',
        };
        final rawSteps =
            (raw['quickFlow'] as Map)[rawSectionName] as List<dynamic>? ??
                const [];
        final parsedSteps = character.quickFlow.stepsFor(phase);
        final availableStepIds = {
          ...character.quickFlow.setup.map((step) => step.id),
          ...parsedSteps.map((step) => step.id),
        };
        expect(parsedSteps, hasLength(rawSteps.length),
            reason:
                '${character.roleId}.$rawSectionName contains an invalid step');
        for (final step in parsedSteps) {
          final token = step.type == QuickFlowStepType.reminder
              ? character.tokens.singleWhere(
                  (candidate) => candidate.quickId == step.tokenId,
                )
              : null;
          expect(interpreter.isStepSupported(step, token: token), isTrue,
              reason:
                  '${character.roleId}.$rawSectionName.${step.id} is unsupported');
          final references = <String>{
            ...step.distinctFrom,
            ...step.allowedTargets.mustMatchOneOf,
            ...step.requires,
            if (step.selection?.stepId != null) step.selection!.stepId!,
            if (step.recipient?.stepId != null) step.recipient!.stepId!,
            ...?step.presentation?.playerSteps,
            if (step.presentation?.playerStep != null)
              step.presentation!.playerStep!,
            if (step.presentation?.characterStep != null)
              step.presentation!.characterStep!,
          };
          expect(availableStepIds, containsAll(references),
              reason:
                  '${character.roleId}.$rawSectionName.${step.id} has a missing step reference');
        }
      }
    }
  });
}
