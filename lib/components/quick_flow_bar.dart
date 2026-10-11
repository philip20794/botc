import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/screens/select_one_charater.dart';
import 'package:blood_on_the_clocktower/screens/quick_flow_selected_character_screen.dart';
import 'package:blood_on_the_clocktower/screens/this-character-slected-you/this_character_selected_you_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuickFlowBar extends StatefulWidget {
  final List<Character> gameCharacters;
  final List<Character> allCharacters;
  final GameStateService gameState;

  const QuickFlowBar({
    super.key,
    required this.gameCharacters,
    required this.allCharacters,
    required this.gameState,
  });

  @override
  State<QuickFlowBar> createState() => _QuickFlowBarState();
}

class _QuickFlowBarState extends State<QuickFlowBar> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _stepKeys = {};
  String? _lastActiveStepKey;

  GameStateService get gameState => widget.gameState;
  List<Character> get gameCharacters => widget.gameCharacters;
  List<Character> get allCharacters => widget.allCharacters;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActive(String? activeKey) {
    if (activeKey == null || activeKey == _lastActiveStepKey) return;
    _lastActiveStepKey = activeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stepContext = _stepKeys[activeKey]?.currentContext;
      if (!mounted || stepContext == null) return;
      Scrollable.ensureVisible(
        stepContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.gameState.quickFlowEntries(widget.gameCharacters);
    if (entries.isEmpty) return const SizedBox.shrink();
    final activeKey = entries
        .where((entry) => widget.gameState
            .isQuickFlowEntryActive(entry, widget.gameCharacters))
        .map((entry) => entry.key)
        .firstOrNull;
    _scrollToActive(activeKey);
    return SizedBox(
      key: const ValueKey('quick-flow-bar'),
      width: MediaQuery.of(context).size.width - 48,
      height: 76,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('quick-flow-scroll-view'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    Container(
                      key: _stepKeys.putIfAbsent(
                          entries[index].key, GlobalKey.new),
                      child: _buildStep(context, entries[index]),
                    ),
                    if (index + 1 < entries.length) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, QuickFlowEntry entry) {
    return switch (entry.step.type) {
      QuickFlowStepType.reminder => _buildReminder(context, entry),
      QuickFlowStepType.reminderCharacterToken =>
        _buildCharacterToken(context, entry),
      QuickFlowStepType.showInfo => _buildInfo(context, entry),
    };
  }

  Widget _frame({
    required QuickFlowEntry entry,
    required Widget child,
    required VoidCallback? onTap,
    bool active = false,
    bool complete = false,
  }) {
    final supported = gameState.isQuickFlowEntrySupported(entry);
    return Tooltip(
      message: entry.step.note ?? entry.step.id,
      child: Opacity(
        opacity: supported ? 1 : 0.55,
        child: GestureDetector(
          key: ValueKey('quick-flow-step-${entry.owner.id}-${entry.step.id}'),
          onTap: supported ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 66,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF493131).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? Colors.amberAccent
                    : complete
                        ? Colors.greenAccent
                        : const Color(0xFF6f678a),
                width: active ? 3 : 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildReminder(BuildContext context, QuickFlowEntry entry) {
    final token = gameState.quickFlowToken(entry);
    final targets = gameState.quickFlowTargets(entry, gameCharacters);
    final complete = targets.isNotEmpty;
    final active = gameState.isQuickFlowEntryActive(entry, gameCharacters);
    return _frame(
      entry: entry,
      active: active,
      complete: complete,
      onTap: () => gameState.activateQuickFlowEntry(entry, gameCharacters),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (token != null)
            CircleAvatar(
              radius: 19,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage(roleImageAssetPath(token.image)),
            )
          else
            const Icon(Icons.warning_amber, color: Colors.white, size: 38),
          Text(
            token?.name ?? entry.step.id,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
          Text(
            targets
                .map((target) => target.playerName)
                .where((name) => name.isNotEmpty)
                .join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterToken(BuildContext context, QuickFlowEntry entry) {
    final selected = gameState.quickFlowSelectedCharacter(
      entry,
      gameCharacters,
      allCharacters,
    );
    final canSelect = entry.step.selection?.type == 'manual' ||
        entry.step.allowManualOverride;
    return _frame(
      entry: entry,
      complete: selected != null,
      onTap: canSelect ? () => _openCharacterSelection(context, entry) : null,
      child: selected == null
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.change_circle, color: Colors.white, size: 38),
                Text('?', style: TextStyle(color: Colors.white)),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CharacterAvatar(
                    character: selected,
                    showIsSelected: false,
                    showName: false,
                    size: 42,
                  ),
                ),
                Text(
                  selected.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ],
            ),
    );
  }

  void _openCharacterSelection(BuildContext context, QuickFlowEntry entry) {
    final localized = AppLocalizations.of(context)!;
    final scriptCharacters = Provider.of<ScriptService>(context, listen: false)
        .resolveCharacters(allCharacters);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectOneCharater(
          charactersToChooseFrom:
              gameState.quickFlowCharacterChoices(entry, scriptCharacters),
          allCharactersToChooseFrom:
              gameState.quickFlowCharacterChoices(entry, allCharacters),
          onConfirm: (character) =>
              gameState.setQuickFlowSelectedCharacter(entry, character),
          onSelectionConfirmed: (selectionContext, character) async {
            final approved = await Navigator.of(selectionContext).push<bool>(
              MaterialPageRoute(
                builder: (_) => QuickFlowSelectedCharacterScreen(
                  character: character,
                ),
              ),
            );
            if (approved == true && selectionContext.mounted) {
              Navigator.of(selectionContext).pop();
            }
          },
          title: localized.chooseACharacter,
          confirmButtonText: localized.assign,
          needToConfirm: false,
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, QuickFlowEntry entry) {
    final ready =
        gameState.isQuickFlowInfoReady(entry, gameCharacters, allCharacters);
    return _frame(
      entry: entry,
      complete: ready,
      onTap: ready ? () => _openInfo(context, entry) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            gameState.quickFlowInfoNeedsConfirmation(entry)
                ? Icons.visibility_outlined
                : Icons.visibility,
            color: ready ? Colors.white : Colors.white38,
            size: 38,
          ),
          Text(
            entry.owner.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ready ? Colors.white : Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInfo(BuildContext context, QuickFlowEntry entry) async {
    final localized = AppLocalizations.of(context)!;
    if (gameState.quickFlowInfoNeedsConfirmation(entry)) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF4a3b5e).withValues(alpha: 0.95),
              title: Text(localized.wantToContinue,
                  style: const TextStyle(color: Colors.white)),
              content: Text(
                entry.step.showOnlyWhen?.reason ?? localized.reallyContinue,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(localized.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(localized.yesContinue),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await gameState.confirmQuickFlowInfo(entry);
      if (!context.mounted) return;
    }
    final info =
        gameState.buildQuickFlowInfo(entry, gameCharacters, allCharacters);
    if (info == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThisCharacterSelectedYouScreen(preparedInfo: info),
      ),
    );
  }
}
