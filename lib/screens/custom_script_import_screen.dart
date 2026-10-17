import 'dart:convert';

import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/script_import.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomScriptImportScreen extends StatefulWidget {
  const CustomScriptImportScreen({super.key, this.pickJson, this.openUri});

  /// Allows a widget test to supply file contents without a platform picker.
  final Future<String?> Function()? pickJson;

  /// Allows a widget test to verify external navigation without a browser.
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<CustomScriptImportScreen> createState() =>
      _CustomScriptImportScreenState();
}

class _CustomScriptImportScreenState extends State<CustomScriptImportScreen> {
  static final _scriptToolUri =
      Uri.parse('https://script.bloodontheclocktower.com/');

  String? _fileError;
  final _jsonController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

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
      await _analyzeSource(source);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileError = AppLocalizations.of(context)!.scriptFileError;
      });
    }
  }

  Future<void> _analyzePastedJson() async {
    final source = _jsonController.text;
    if (source.trim().isEmpty) return;
    await _analyzeSource(source);
  }

  Future<void> _analyzeSource(String source) async {
    try {
      final draft = await context
          .read<ScriptService>()
          .inspectImportJson(source, context.read<CharacterService>());
      if (!mounted) return;
      if (draft.validationIssues
          .any((issue) => issue.type == ScriptImportIssueType.invalidJson)) {
        setState(() {
          _fileError = AppLocalizations.of(context)!.scriptInvalidJson;
        });
        return;
      }
      setState(() => _fileError = null);
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScriptImportPreviewScreen(initialDraft: draft),
        ),
      );
      if (saved == true && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fileError = AppLocalizations.of(context)!.scriptImportError;
      });
    }
  }

  Future<void> _openScriptTool() async {
    final opened = await (widget.openUri?.call(_scriptToolUri) ??
        launchUrl(_scriptToolUri, mode: LaunchMode.externalApplication));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.scriptToolError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AppBackground(
      child: Theme(
        data: withScriptComplexityEditorTheme(GrimoireTheme.build()),
        child: Builder(
            builder: (context) => Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    title: Text(strings.importScript),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GrimoirePanel(
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                key: const ValueKey('scriptImportPickFile'),
                                onPressed: _selectFile,
                                icon: const Icon(Icons.upload_file),
                                label: Text(strings.selectScriptFile),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      strings.or,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                key: const ValueKey('scriptImportPasteJson'),
                                controller: _jsonController,
                                minLines: 5,
                                maxLines: 8,
                                keyboardType: TextInputType.multiline,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: strings.pasteJson,
                                  hintText: strings.pasteJsonHint,
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                key: const ValueKey('scriptImportAnalyzeText'),
                                onPressed: _jsonController.text.trim().isEmpty
                                    ? null
                                    : _analyzePastedJson,
                                icon: const Icon(Icons.manage_search),
                                label: Text(strings.analyzeScript),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GrimoirePanel(
                        padding: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.scriptsCreateDiscover,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(strings.scriptsCreateDiscoverDescription),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const ValueKey('scriptImportOpenTool'),
                                  onPressed: _openScriptTool,
                                  icon: const Icon(Icons.open_in_new),
                                  label: Text(strings.openScriptTool),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_fileError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorCard(message: _fileError!),
                      ],
                    ],
                  ),
                )),
      ),
    );
  }
}

class ScriptImportPreviewScreen extends StatefulWidget {
  const ScriptImportPreviewScreen({super.key, required this.initialDraft});

  final ScriptImportResult initialDraft;

  @override
  State<ScriptImportPreviewScreen> createState() =>
      _ScriptImportPreviewScreenState();
}

class _ScriptImportPreviewScreenState extends State<ScriptImportPreviewScreen> {
  late ScriptImportResult _draft;
  late final TextEditingController _nameController;
  bool _isSaving = false;
  double? _storytellerComplexity;
  double? _playerComplexity;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _nameController = TextEditingController(text: _draft.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _mapRole(ImportedScriptRole role) async {
    final roleId = await showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: withScriptComplexityEditorTheme(GrimoireTheme.build()),
        child: _RoleMappingDialog(
          excludedRoleIds: _draft.roles
              .where((candidate) => candidate.index != role.index)
              .map((candidate) => candidate.resolvedRoleId)
              .whereType<String>()
              .toSet(),
        ),
      ),
    );
    if (roleId == null || !mounted) return;
    final mapped = await context.read<ScriptService>().mapImportedRole(
          _draft,
          roleIndex: role.index,
          canonicalRoleId: roleId,
          characterService: context.read<CharacterService>(),
        );
    if (mounted) setState(() => _draft = mapped);
  }

  Future<void> _confirmImport() async {
    final namedDraft = _draft.withName(_nameController.text);
    if (!namedDraft.canBeConfirmed || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await context.read<ScriptService>().confirmImport(
            namedDraft,
            storytellerComplexity: _storytellerComplexity,
            playerComplexity: _playerComplexity,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.scriptSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.scriptImportError)),
        );
      }
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
    final canSave = draft.withName(_nameController.text).canBeConfirmed;
    return AppBackground(
      child: Theme(
        data: withScriptComplexityEditorTheme(GrimoireTheme.build()),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(strings.scriptPreview),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: ListView(
            key: const ValueKey('scriptImportPreview'),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.scriptPreview,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('scriptImportName'),
                        controller: _nameController,
                        enabled: !_isSaving,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: strings.scriptName),
                      ),
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
                        child: _ErrorCard(message: _issueText(strings, issue)),
                      )),
              if (draft.unresolvedRoles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(strings.unknownImportedRoles,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...draft.unresolvedRoles.map((role) => Card(
                      child: ListTile(
                        title: Text(role.sourceId ?? strings.scriptInvalidRole),
                        subtitle: Text(_issueText(strings, role.issue!)),
                        trailing: OutlinedButton(
                          key: ValueKey('scriptImportMap-${role.index}'),
                          onPressed: _isSaving ? null : () => _mapRole(role),
                          child: Text(strings.mapRole),
                        ),
                      ),
                    )),
              ],
              if (draft.issues.any((issue) =>
                  issue.type == ScriptImportIssueType.duplicateRoleId))
                ...draft.issues
                    .where((issue) =>
                        issue.type == ScriptImportIssueType.duplicateRoleId)
                    .map((issue) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child:
                              _ErrorCard(message: _issueText(strings, issue)),
                        )),
              const SizedBox(height: 16),
              ScriptComplexityEditorField(
                key: const ValueKey('scriptImportStorytellerComplexity'),
                asset: 'assets/ui/script_meta/storyteller_complexity.png',
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
                onChanged: (value) => setState(() => _playerComplexity = value),
              ),
              const SizedBox(height: 16),
              if (_nameController.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(strings.enterScriptNameBeforeSaving),
                ),
              if (draft.unresolvedRoles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(strings.resolveRolesBeforeSaving),
                ),
              ElevatedButton(
                key: const ValueKey('scriptImportConfirm'),
                onPressed: canSave && !_isSaving ? _confirmImport : null,
                child: Text(strings.confirmImport),
              ),
            ],
          ),
        ),
      ),
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
