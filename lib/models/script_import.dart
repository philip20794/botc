enum ScriptImportIssueType {
  invalidJson,
  invalidStructure,
  invalidMetadata,
  invalidRoleEntry,
  unknownRoleId,
  ambiguousRoleId,
  duplicateRoleId,
  unsupportedHomebrewDefinition,
}

class ScriptImportIssue {
  final ScriptImportIssueType type;
  final String message;
  final int? roleIndex;
  final String? sourceId;
  final List<String> candidateRoleIds;

  ScriptImportIssue({
    required this.type,
    required this.message,
    this.roleIndex,
    this.sourceId,
    List<String> candidateRoleIds = const [],
  }) : candidateRoleIds = List.unmodifiable(candidateRoleIds);
}

class ImportedScriptRole {
  final int index;
  final String? sourceId;
  final String? resolvedRoleId;
  final ScriptImportIssue? issue;

  const ImportedScriptRole({
    required this.index,
    this.sourceId,
    this.resolvedRoleId,
    this.issue,
  });

  bool get isResolved => resolvedRoleId != null;

  ImportedScriptRole withResolvedRoleId(String roleId) {
    return ImportedScriptRole(
      index: index,
      sourceId: sourceId,
      resolvedRoleId: roleId,
    );
  }
}

class ScriptImportResult {
  final String? name;
  final String? author;
  final List<ImportedScriptRole> roles;
  final List<ScriptImportIssue> validationIssues;

  ScriptImportResult({
    this.name,
    this.author,
    List<ImportedScriptRole> roles = const [],
    List<ScriptImportIssue> validationIssues = const [],
  })  : roles = List.unmodifiable(roles),
        validationIssues = List.unmodifiable(validationIssues);

  List<ImportedScriptRole> get unresolvedRoles =>
      roles.where((role) => !role.isResolved).toList(growable: false);

  List<ScriptImportIssue> get issues => List.unmodifiable([
        ...validationIssues,
        ...unresolvedRoles
            .where((role) => role.issue != null)
            .map((role) => role.issue!),
        ..._duplicateRoleIssues(),
      ]);

  bool get canBeConfirmed =>
      name != null &&
      name!.trim().isNotEmpty &&
      unresolvedRoles.isEmpty &&
      issues.isEmpty;

  List<String> get resolvedRoleIds {
    if (!canBeConfirmed) {
      throw StateError('The imported script is not fully resolved.');
    }
    return List.unmodifiable(
      roles.map((role) => role.resolvedRoleId!),
    );
  }

  ScriptImportResult withName(String name) {
    return ScriptImportResult(
      name: name.trim(),
      author: author,
      roles: roles,
      validationIssues: validationIssues,
    );
  }

  ScriptImportResult withResolvedRole(
    int roleIndex,
    String roleId,
  ) {
    var found = false;
    final updatedRoles = roles.map((role) {
      if (role.index != roleIndex) {
        return role;
      }
      found = true;
      return role.withResolvedRoleId(roleId);
    }).toList();
    if (!found) {
      throw ArgumentError.value(roleIndex, 'roleIndex', 'Unknown import role');
    }
    return ScriptImportResult(
      name: name,
      author: author,
      roles: updatedRoles,
      validationIssues: validationIssues,
    );
  }

  List<ScriptImportIssue> _duplicateRoleIssues() {
    final issues = <ScriptImportIssue>[];
    final sourceIds = <String, List<ImportedScriptRole>>{};
    final resolvedIds = <String, List<ImportedScriptRole>>{};
    for (final role in roles) {
      final sourceId = role.sourceId;
      if (sourceId != null) {
        (sourceIds[sourceId] ??= []).add(role);
      }
      final resolvedRoleId = role.resolvedRoleId;
      if (resolvedRoleId != null) {
        (resolvedIds[resolvedRoleId] ??= []).add(role);
      }
    }
    for (final entry
        in sourceIds.entries.where((entry) => entry.value.length > 1)) {
      for (final role in entry.value) {
        issues.add(ScriptImportIssue(
          type: ScriptImportIssueType.duplicateRoleId,
          message: 'The role ID "${entry.key}" occurs more than once.',
          roleIndex: role.index,
          sourceId: entry.key,
        ));
      }
    }
    for (final entry
        in resolvedIds.entries.where((entry) => entry.value.length > 1)) {
      final hasMatchingSourceIds = entry.value.every(
        (role) => role.sourceId == entry.key,
      );
      if (hasMatchingSourceIds) {
        continue;
      }
      for (final role in entry.value) {
        issues.add(ScriptImportIssue(
          type: ScriptImportIssueType.duplicateRoleId,
          message: 'Multiple imported entries resolve to "${entry.key}".',
          roleIndex: role.index,
          sourceId: role.sourceId,
        ));
      }
    }
    return issues;
  }
}
