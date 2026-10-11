enum QuickFlowPhase { setup, firstNight, otherNights }

enum QuickFlowStepType { reminder, reminderCharacterToken, showInfo }

enum QuickFlowReminderOperation { move, setOnce, append }

class QuickFlow {
  final List<QuickFlowStep> setup;
  final List<QuickFlowStep> firstNight;
  final List<QuickFlowStep> otherNights;

  const QuickFlow({
    this.setup = const [],
    this.firstNight = const [],
    this.otherNights = const [],
  });

  factory QuickFlow.fromJson(dynamic json) {
    if (json is! Map) return const QuickFlow();
    return QuickFlow(
      setup: _parseSteps(json['setup']),
      firstNight: _parseSteps(json['firstNight']),
      otherNights: _parseSteps(json['otherNights']),
    );
  }

  static List<QuickFlowStep> _parseSteps(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => QuickFlowStep.tryFromJson(
              Map<String, dynamic>.from(item),
            ))
        .whereType<QuickFlowStep>()
        .toList(growable: false);
  }

  List<QuickFlowStep> stepsFor(QuickFlowPhase phase) => switch (phase) {
        QuickFlowPhase.setup => setup,
        QuickFlowPhase.firstNight => firstNight,
        QuickFlowPhase.otherNights => otherNights,
      };

  Map<String, dynamic> toJson() => {
        if (setup.isNotEmpty)
          'setup': setup.map((step) => step.toJson()).toList(),
        if (firstNight.isNotEmpty)
          'firstNight': firstNight.map((step) => step.toJson()).toList(),
        if (otherNights.isNotEmpty)
          'otherNights': otherNights.map((step) => step.toJson()).toList(),
      };
}

class QuickFlowStep {
  final String id;
  final QuickFlowStepType type;
  final String? tokenId;
  final QuickFlowReminderOperation? operation;
  final String? group;
  final List<String> distinctFrom;
  final QuickFlowTargetRules allowedTargets;
  final String? nightConstraint;
  final QuickFlowCharacterSelection? selection;
  final List<String> allowedFractions;
  final bool allowManualOverride;
  final QuickFlowRecipient? recipient;
  final QuickFlowPresentation? presentation;
  final List<String> requires;
  final QuickFlowVisibility? showOnlyWhen;
  final String? note;

  const QuickFlowStep({
    required this.id,
    required this.type,
    this.tokenId,
    this.operation,
    this.group,
    this.distinctFrom = const [],
    this.allowedTargets = const QuickFlowTargetRules(),
    this.nightConstraint,
    this.selection,
    this.allowedFractions = const [],
    this.allowManualOverride = false,
    this.recipient,
    this.presentation,
    this.requires = const [],
    this.showOnlyWhen,
    this.note,
  });

  static QuickFlowStep? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final rawType = json['type'];
    if (id is! String || id.trim().isEmpty || rawType is! String) return null;
    final type = switch (rawType) {
      'reminder' => QuickFlowStepType.reminder,
      'reminderCharacterToken' => QuickFlowStepType.reminderCharacterToken,
      'showInfo' => QuickFlowStepType.showInfo,
      _ => null,
    };
    if (type == null) return null;

    final tokenId = json['tokenId'] is String ? json['tokenId'] as String : null;
    final operation = switch (json['operation']) {
      'move' => QuickFlowReminderOperation.move,
      'setOnce' => QuickFlowReminderOperation.setOnce,
      'append' => QuickFlowReminderOperation.append,
      _ => null,
    };
    if (type == QuickFlowStepType.reminder &&
        (tokenId == null || tokenId.isEmpty || operation == null)) {
      return null;
    }

    return QuickFlowStep(
      id: id,
      type: type,
      tokenId: tokenId,
      operation: operation,
      group: json['group'] is String ? json['group'] as String : null,
      distinctFrom: _strings(json['distinctFrom']),
      allowedTargets: QuickFlowTargetRules.fromJson(json['allowedTargets']),
      nightConstraint: json['nightConstraint'] is String
          ? json['nightConstraint'] as String
          : null,
      selection: QuickFlowCharacterSelection.fromJson(json['selection']),
      allowedFractions: _strings(json['allowedFractions']),
      allowManualOverride: json['allowManualOverride'] == true,
      recipient: QuickFlowRecipient.fromJson(json['recipient']),
      presentation: QuickFlowPresentation.fromJson(json['presentation']),
      requires: _strings(json['requires']),
      showOnlyWhen: QuickFlowVisibility.fromJson(json['showOnlyWhen']),
      note: json['note'] is String ? json['note'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': switch (type) {
          QuickFlowStepType.reminder => 'reminder',
          QuickFlowStepType.reminderCharacterToken =>
            'reminderCharacterToken',
          QuickFlowStepType.showInfo => 'showInfo',
        },
        if (tokenId != null) 'tokenId': tokenId,
        if (operation != null)
          'operation': switch (operation!) {
            QuickFlowReminderOperation.move => 'move',
            QuickFlowReminderOperation.setOnce => 'setOnce',
            QuickFlowReminderOperation.append => 'append',
          },
        if (group != null) 'group': group,
        if (distinctFrom.isNotEmpty) 'distinctFrom': distinctFrom,
        if (!allowedTargets.isEmpty)
          'allowedTargets': allowedTargets.toJson(),
        if (nightConstraint != null) 'nightConstraint': nightConstraint,
        if (selection != null) 'selection': selection!.toJson(),
        if (allowedFractions.isNotEmpty)
          'allowedFractions': allowedFractions,
        if (allowManualOverride) 'allowManualOverride': true,
        if (recipient != null) 'recipient': recipient!.toJson(),
        if (presentation != null) 'presentation': presentation!.toJson(),
        if (requires.isNotEmpty) 'requires': requires,
        if (showOnlyWhen != null)
          'showOnlyWhen': showOnlyWhen!.toJson(),
        if (note != null) 'note': note,
      };
}

class QuickFlowTargetRules {
  final List<String> fractions;
  final List<String> excludeFractions;
  final List<String> alignment;
  final List<String> roles;
  final bool excludeAbilityOwner;
  final bool aliveOnly;
  final List<String> mustMatchOneOf;

  const QuickFlowTargetRules({
    this.fractions = const [],
    this.excludeFractions = const [],
    this.alignment = const [],
    this.roles = const [],
    this.excludeAbilityOwner = false,
    this.aliveOnly = false,
    this.mustMatchOneOf = const [],
  });

  factory QuickFlowTargetRules.fromJson(dynamic json) {
    if (json is! Map) return const QuickFlowTargetRules();
    return QuickFlowTargetRules(
      fractions: _strings(json['fractions']),
      excludeFractions: _strings(json['excludeFractions']),
      alignment: _strings(json['alignment']),
      roles: _strings(json['roles']),
      excludeAbilityOwner: json['excludeAbilityOwner'] == true,
      aliveOnly: json['aliveOnly'] == true,
      mustMatchOneOf: _strings(json['mustMatchOneOf']),
    );
  }

  bool get isEmpty =>
      fractions.isEmpty &&
      excludeFractions.isEmpty &&
      alignment.isEmpty &&
      roles.isEmpty &&
      !excludeAbilityOwner &&
      !aliveOnly &&
      mustMatchOneOf.isEmpty;

  Map<String, dynamic> toJson() => {
        if (fractions.isNotEmpty) 'fractions': fractions,
        if (excludeFractions.isNotEmpty)
          'excludeFractions': excludeFractions,
        if (alignment.isNotEmpty) 'alignment': alignment,
        if (roles.isNotEmpty) 'roles': roles,
        if (excludeAbilityOwner) 'excludeAbilityOwner': true,
        if (aliveOnly) 'aliveOnly': true,
        if (mustMatchOneOf.isNotEmpty) 'mustMatchOneOf': mustMatchOneOf,
      };
}

class QuickFlowCharacterSelection {
  final String type;
  final String? stepId;

  const QuickFlowCharacterSelection({required this.type, this.stepId});

  static QuickFlowCharacterSelection? fromJson(dynamic json) {
    if (json is! Map) return null;
    final type = json['type'];
    if (type != 'manual' && type != 'fromReminderTarget') return null;
    final stepId = json['stepId'] is String ? json['stepId'] as String : null;
    if (type == 'fromReminderTarget' &&
        (stepId == null || stepId.isEmpty)) {
      return null;
    }
    return QuickFlowCharacterSelection(type: type as String, stepId: stepId);
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (stepId != null) 'stepId': stepId,
      };
}

class QuickFlowRecipient {
  final String type;
  final String? stepId;

  const QuickFlowRecipient({required this.type, this.stepId});

  static QuickFlowRecipient? fromJson(dynamic json) {
    if (json is! Map || json['type'] is! String) return null;
    return QuickFlowRecipient(
      type: json['type'] as String,
      stepId: json['stepId'] is String ? json['stepId'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (stepId != null) 'stepId': stepId,
      };
}

class QuickFlowPresentation {
  final String kind;
  final List<String> playerSteps;
  final String? playerStep;
  final String? characterStep;
  final String? sourceRoleId;
  final String? pointToRolePlayer;

  const QuickFlowPresentation({
    required this.kind,
    this.playerSteps = const [],
    this.playerStep,
    this.characterStep,
    this.sourceRoleId,
    this.pointToRolePlayer,
  });

  static QuickFlowPresentation? fromJson(dynamic json) {
    if (json is! Map || json['kind'] is! String) return null;
    return QuickFlowPresentation(
      kind: json['kind'] as String,
      playerSteps: _strings(json['playerSteps']),
      playerStep:
          json['playerStep'] is String ? json['playerStep'] as String : null,
      characterStep: json['characterStep'] is String
          ? json['characterStep'] as String
          : null,
      sourceRoleId: json['sourceRoleId'] is String
          ? json['sourceRoleId'] as String
          : null,
      pointToRolePlayer: json['pointToRolePlayer'] is String
          ? json['pointToRolePlayer'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (playerSteps.isNotEmpty) 'playerSteps': playerSteps,
        if (playerStep != null) 'playerStep': playerStep,
        if (characterStep != null) 'characterStep': characterStep,
        if (sourceRoleId != null) 'sourceRoleId': sourceRoleId,
        if (pointToRolePlayer != null)
          'pointToRolePlayer': pointToRolePlayer,
      };
}

class QuickFlowVisibility {
  final String type;
  final String? reason;

  const QuickFlowVisibility({required this.type, this.reason});

  static QuickFlowVisibility? fromJson(dynamic json) {
    if (json is! Map || json['type'] is! String) return null;
    return QuickFlowVisibility(
      type: json['type'] as String,
      reason: json['reason'] is String ? json['reason'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (reason != null) 'reason': reason,
      };
}

List<String> _strings(dynamic value) => value is List
    ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
    : const [];
