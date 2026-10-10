import 'dart:convert';

import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/script_import.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _importBackground = Color(0xFF4a3b5e);
const _importSurface = Color(0xFF6f678a);

ThemeData _customScriptImportTheme(ThemeData base) {
  final colorScheme = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    primary: _importSurface,
    onPrimary: Colors.white,
    surface: _importSurface,
    onSurface: Colors.white,
  );
  final border = OutlineInputBorder(
    borderSide: const BorderSide(color: Colors.white54),
    borderRadius: BorderRadius.circular(8),
  );
  return withScriptComplexityEditorTheme(base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: _importBackground,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: _importBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: _importSurface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: _importSurface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: _importBackground,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIconColor: Colors.white70,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _importSurface,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white70),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
    ),
  ));
}

class CustomScriptImportScreen extends StatefulWidget {
  const CustomScriptImportScreen({super.key, this.pickJson});

  /// Allows a widget test to supply file contents without a platform picker.
  final Future<String?> Function()? pickJson;

  @override
  State<CustomScriptImportScreen> createState() =>
      _CustomScriptImportScreenState();
}

class _CustomScriptImportScreenState extends State<CustomScriptImportScreen> {
  ScriptImportResult? _draft;
  String? _fileError;
  bool _isSaving = false;
  double? _storytellerComplexity;
  double? _playerComplexity;

  Future<String?> _pickJsonFile() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (selection == null) return null;
    final bytes = selection.files.single.bytes;
    if (bytes == null) {
      throw StateError('The selected file did not provide file data.');
    }
    return utf8.decode(bytes);
  }

  Future<void> _selectFile() async {
    try {
      final source = await (widget.pickJson ?? _pickJsonFile)();
      if (source == null) return;
      final draft = await context
          .read<ScriptService>()
          .inspectImportJson(source, context.read<CharacterService>());
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _fileError = null;
        _storytellerComplexity = null;
        _playerComplexity = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draft = null;
        _fileError = AppLocalizations.of(context)!.scriptFileError;
      });
    }
  }

  Future<void> _mapRole(ImportedScriptRole role) async {
    final roleId = await showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: _customScriptImportTheme(Theme.of(this.context)),
        child: _RoleMappingDialog(
          excludedRoleIds: _draft!.roles
              .where((candidate) => candidate.index != role.index)
              .map((candidate) => candidate.resolvedRoleId)
              .whereType<String>()
              .toSet(),
        ),
      ),
    );
    if (roleId == null || !mounted) return;
    final mapped = await context.read<ScriptService>().mapImportedRole(
          _draft!,
          roleIndex: role.index,
          canonicalRoleId: roleId,
          characterService: context.read<CharacterService>(),
        );
    if (!mounted) return;
    setState(() => _draft = mapped);
  }

  Future<void> _confirmImport() async {
    final draft = _draft;
    if (draft == null || !draft.canBeConfirmed) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ScriptService>().confirmImport(
            draft,
            storytellerComplexity: _storytellerComplexity,
            playerComplexity: _playerComplexity,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.scriptSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.scriptImportError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _issueText(AppLocalizations strings, ScriptImportIssue issue) {
    return switch (issue.type) {
      ScriptImportIssueType.invalidJson => strings.scriptInvalidJson,
      ScriptImportIssueType.invalidStructure => strings.scriptInvalidStructure,
      ScriptImportIssueType.invalidMetadata => strings.scriptInvalidMetadata,
      ScriptImportIssueType.invalidRoleEntry => strings.scriptInvalidRole,
      ScriptImportIssueType.unknownRoleId =>
        strings.scriptUnknownRole(issue.sourceId ?? ''),
      ScriptImportIssueType.ambiguousRoleId =>
        strings.scriptAmbiguousRole(issue.sourceId ?? ''),
      ScriptImportIssueType.duplicateRoleId =>
        strings.scriptDuplicateRole(issue.sourceId ?? ''),
      ScriptImportIssueType.unsupportedHomebrewDefinition =>
        strings.scriptUnsupportedRole(issue.sourceId ?? ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final draft = _draft;
    return Theme(
      data: _customScriptImportTheme(Theme.of(context)),
      child: Builder(
          builder: (context) => Scaffold(
                appBar: AppBar(title: Text(strings.importScript)),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ElevatedButton.icon(
                      key: const ValueKey('scriptImportPickFile'),
                      onPressed: _isSaving ? null : _selectFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(strings.selectScriptFile),
                    ),
                    if (_fileError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorCard(message: _fileError!),
                    ],
                    if (draft != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(strings.scriptPreview,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(draft.name ?? strings.scriptImportError),
                              if (draft.author != null)
                                Text(strings.scriptAuthor(draft.author!)),
                              Text(strings.scriptRoleCount(draft.roles.length)),
                            ],
                          ),
                        ),
                      ),
                      ...draft.issues
                          .where((issue) => issue.roleIndex == null)
                          .map((issue) => Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _ErrorCard(
                                    message: _issueText(strings, issue)),
                              )),
                      if (draft.unresolvedRoles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(strings.unknownImportedRoles,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...draft.unresolvedRoles.map((role) => Card(
                              child: ListTile(
                                title: Text(
                                    role.sourceId ?? strings.scriptInvalidRole),
                                subtitle:
                                    Text(_issueText(strings, role.issue!)),
                                trailing: OutlinedButton(
                                  key:
                                      ValueKey('scriptImportMap-${role.index}'),
                                  onPressed:
                                      _isSaving ? null : () => _mapRole(role),
                                  child: Text(strings.mapRole),
                                ),
                              ),
                            )),
                      ],
                      if (draft.issues.any((issue) =>
                          issue.type == ScriptImportIssueType.duplicateRoleId))
                        ...draft.issues
                            .where((issue) =>
                                issue.type ==
                                ScriptImportIssueType.duplicateRoleId)
                            .map((issue) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _ErrorCard(
                                      message: _issueText(strings, issue)),
                                )),
                      const SizedBox(height: 16),
                      ScriptComplexityEditorField(
                        key:
                            const ValueKey('scriptImportStorytellerComplexity'),
                        asset:
                            'assets/ui/script_meta/storyteller_complexity.png',
                        label: strings.storytellerComplexity,
                        value: _storytellerComplexity,
                        onChanged: (value) =>
                            setState(() => _storytellerComplexity = value),
                      ),
                      ScriptComplexityEditorField(
                        key: const ValueKey('scriptImportPlayerComplexity'),
                        asset: 'assets/ui/script_meta/player_complexity.png',
                        label: strings.playerComplexity,
                        value: _playerComplexity,
                        onChanged: (value) =>
                            setState(() => _playerComplexity = value),
                      ),
                      const SizedBox(height: 16),
                      if (!draft.canBeConfirmed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(strings.resolveRolesBeforeSaving),
                        ),
                      ElevatedButton(
                        key: const ValueKey('scriptImportConfirm'),
                        onPressed: draft.canBeConfirmed && !_isSaving
                            ? _confirmImport
                            : null,
                        child: Text(strings.confirmImport),
                      ),
                    ],
                  ],
                ),
              )),
    );
  }
}

class _RoleMappingDialog extends StatefulWidget {
  const _RoleMappingDialog({required this.excludedRoleIds});

  final Set<String> excludedRoleIds;

  @override
  State<_RoleMappingDialog> createState() => _RoleMappingDialogState();
}

class _RoleMappingDialogState extends State<_RoleMappingDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final normalizedQuery = _query.trim().toLowerCase();
    final roles = context
        .read<CharacterService>()
        .allCharacters
        .where((role) => !widget.excludedRoleIds.contains(role.roleId))
        .where((role) =>
            normalizedQuery.isEmpty ||
            role.name.toLowerCase().contains(normalizedQuery) ||
            role.roleId.contains(normalizedQuery))
        .toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return AlertDialog(
      title: Text(strings.mapRole),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: strings.searchRoles,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: roles.isEmpty
                  ? Center(child: Text(strings.noRolesFound))
                  : ListView.builder(
                      itemCount: roles.length,
                      itemBuilder: (context, index) {
                        final role = roles[index];
                        return ListTile(
                          title: Text(role.name),
                          subtitle: Text(role.roleId),
                          onTap: () => Navigator.of(context).pop(role.roleId),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}
