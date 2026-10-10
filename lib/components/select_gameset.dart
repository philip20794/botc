import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/screens/custom_script_import_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectGameset extends StatelessWidget {
  const SelectGameset({
    super.key,
    required this.disabled,
    this.scriptWidth = 180,
    this.showManagementAction = true,
  });

  static const _importAction = '__import_custom_script__';
  final bool disabled;
  final double scriptWidth;
  final bool showManagementAction;

  Future<void> _selectScript(BuildContext context, String id) async {
    if (disabled) return;
    final gameState = context.read<GameStateService>();
    if (gameState.gameIsRunning()) {
      _showMessage(
          context, AppLocalizations.of(context)!.scriptChangeWhileRunning);
      return;
    }
    final characters = context.read<CharacterService>();
    characters.reset();
    await gameState.selectScript(id, characters.gameCharacters);
  }

  Future<void> _openImporter(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CustomScriptImportScreen()),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showManager(BuildContext context) async {
    final strings = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF4a3b5e),
      builder: (sheetContext) => Theme(
        data: _customScriptTheme(Theme.of(context)),
        child: SafeArea(
          child: Consumer<ScriptService>(
            builder: (context, scripts, _) => ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(strings.editComplexities),
                  subtitle: ScriptComplexitySummary(
                    scriptId: scripts.selectedScriptId,
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showComplexityEditor(
                        context, scripts.selectedScript);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(strings.importScript),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _openImporter(context);
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(strings.customScripts,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (scripts.customScripts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(strings.noCustomScripts),
                  ),
                ...scripts.customScripts.map(
                  (script) => _CustomScriptTile(
                    script: script,
                    onEdit: () => _showComplexityEditor(context, script),
                    onDelete: () => _deleteScript(context, script),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteScript(BuildContext context, BotcScript script) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _customScriptTheme(Theme.of(context)),
        child: AlertDialog(
          title: Text(strings.deleteScript),
          content: Text(strings.deleteScriptConfirmation(script.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.deleteScript),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final gameState = context.read<GameStateService>();
    if (gameState.gameIsRunning()) {
      _showMessage(context, strings.scriptChangeWhileRunning);
      return;
    }
    final scripts = context.read<ScriptService>();
    final characters = context.read<CharacterService>();
    final deletesSelectedScript = scripts.selectedScriptId == script.id;
    if (deletesSelectedScript) characters.reset();
    final deleted = await gameState.removeCustomScript(
      script.id,
      characters.gameCharacters,
    );
    if (!context.mounted) return;
    _showMessage(
      context,
      deleted ? strings.scriptDeleted : strings.scriptChangeWhileRunning,
    );
  }

  Future<void> _showComplexityEditor(
    BuildContext context,
    BotcScript script,
  ) async {
    final strings = AppLocalizations.of(context)!;
    final service = context.read<ScriptService>();
    var storyteller = service.storytellerComplexityFor(script.id);
    var player = service.playerComplexityFor(script.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _customScriptTheme(Theme.of(context)),
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(strings.editComplexities),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScriptComplexityEditorField(
                    asset: 'assets/ui/script_meta/storyteller_complexity.png',
                    label: strings.storytellerComplexity,
                    value: storyteller,
                    onChanged: (value) => setState(() => storyteller = value),
                  ),
                  ScriptComplexityEditorField(
                    asset: 'assets/ui/script_meta/player_complexity.png',
                    label: strings.playerComplexity,
                    value: player,
                    onChanged: (value) => setState(() => player = value),
                  ),
                ],
              ),
            ),
            actions: [
              if (service.hasComplexityOverride(script.id))
                TextButton(
                  onPressed: () async {
                    await service.resetComplexities(script.id);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(strings.resetComplexities),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed: () async {
                  await service.setComplexities(
                    script.id,
                    storytellerComplexity: storyteller,
                    playerComplexity: player,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scripts = context.watch<ScriptService>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: scriptWidth,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF6f678a),
              iconEnabledColor: Colors.white,
              value: scripts.selectedScriptId,
              onChanged: disabled
                  ? null
                  : (id) async {
                      if (id == null) return;
                      if (id == _importAction) {
                        await _openImporter(context);
                        return;
                      }
                      await _selectScript(context, id);
                    },
              items: [
                ...ScriptService.standardScripts.map(
                  (script) => _scriptItem(script, disabled, scriptWidth),
                ),
                ...scripts.customScripts.map(
                  (script) => _scriptItem(script, disabled, scriptWidth),
                ),
                DropdownMenuItem<String>(
                  value: _importAction,
                  child: SizedBox(
                    width: scriptWidth,
                    child: Row(
                      children: [
                        Icon(Icons.upload_file,
                            color: disabled ? Colors.grey : Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.importScript,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: disabled ? Colors.grey : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showManagementAction)
          IconButton(
            tooltip: AppLocalizations.of(context)!.manageScripts,
            color: disabled ? Colors.grey : Colors.white,
            onPressed: disabled ? null : () => _showManager(context),
            icon: const Icon(Icons.more_vert),
          ),
      ],
    );
  }

  DropdownMenuItem<String> _scriptItem(
    BotcScript script,
    bool disabled,
    double width,
  ) {
    return DropdownMenuItem<String>(
      value: script.id,
      child: SizedBox(
        width: width,
        child: Text(
          script.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: disabled ? Colors.grey : Colors.white),
        ),
      ),
    );
  }
}

ThemeData _customScriptTheme(ThemeData base) {
  final colorScheme = base.colorScheme.copyWith(
    brightness: Brightness.dark,
    primary: const Color(0xFF6f678a),
    onPrimary: Colors.white,
    surface: const Color(0xFF6f678a),
    onSurface: Colors.white,
  );
  return withScriptComplexityEditorTheme(base.copyWith(
    colorScheme: colorScheme,
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: const Color(0xFF4a3b5e),
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: const Color(0xFF6f678a),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    dividerColor: Colors.white24,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Colors.white,
      titleTextStyle: TextStyle(color: Colors.white),
      subtitleTextStyle: TextStyle(color: Colors.white70),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
    ),
  ));
}

class _CustomScriptTile extends StatelessWidget {
  const _CustomScriptTile({
    required this.script,
    required this.onEdit,
    required this.onDelete,
  });

  final BotcScript script;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(script.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([
            if (script.author != null) strings.scriptAuthor(script.author!),
            strings.scriptRoleCount(script.roleIds.length),
          ].join(' · ')),
          ScriptComplexitySummary(scriptId: script.id, iconSize: 22),
        ],
      ),
      trailing: Wrap(
        children: [
          IconButton(
            tooltip: strings.editComplexities,
            icon: const Icon(Icons.tune),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: strings.deleteScript,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
