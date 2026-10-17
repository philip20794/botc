import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/screens/select_one_charater.dart';
import 'package:blood_on_the_clocktower/screens/quick_flow_selected_character_screen.dart';
import 'package:blood_on_the_clocktower/screens/this-character-slected-you/this_character_selected_you_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

enum _QuickFlowInfoDecision { cancel, skip, show }

class QuickFlowBar extends StatefulWidget {
  final List<Character> gameCharacters;
  final List<Character> allCharacters;
  final GameStateService gameState;
  final bool readOnly;

  const QuickFlowBar({
    super.key,
    required this.gameCharacters,
    required this.allCharacters,
    required this.gameState,
    this.readOnly = false,
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
    final settingsService = Provider.of<SettingsService>(context);
    final reminderBarHeight =
        math.max(76.0, settingsService.selectedReminderTokenSize * 1.15);
    final activeKey = entries
        .where((entry) => widget.gameState
            .isQuickFlowEntryActive(entry, widget.gameCharacters))
        .map((entry) => entry.key)
        .firstOrNull;
    _scrollToActive(activeKey);
    return SizedBox(
      key: const ValueKey('quick-flow-bar'),
      width: MediaQuery.of(context).size.width - 48,
      height: reminderBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('quick-flow-scroll-view'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          // The bar is placed above the playground. Let empty viewport space
          // fall through to character drags; only its actual chip children
          // participate in the gesture arena.
          hitTestBehavior: HitTestBehavior.deferToChild,
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
      QuickFlowStepType.roleChange => _buildRoleChange(context, entry),
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
    final settingsService = Provider.of<SettingsService>(context);
    final isActive =
        active || gameState.isQuickFlowEntryActive(entry, gameCharacters);
    final cardWidth = isActive
        ? settingsService.selectedReminderTokenSize
        : settingsService.unselectedReminderTokenSize;
    final cardHeight = cardWidth * 1.15;
    return Tooltip(
      message: entry.step.note ?? entry.step.id,
      child: Opacity(
        opacity: supported ? 1 : 0.55,
        child: GestureDetector(
          key: ValueKey('quick-flow-step-${entry.owner.id}-${entry.step.id}'),
          onTap: !widget.readOnly && supported ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: cardWidth,
            height: cardHeight,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: const Color(0xFF493131).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? Colors.amberAccent
                    : complete
                        ? Colors.greenAccent
                        : const Color(0xFF6f678a),
                width: isActive ? 3 : 1.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(width: 66, height: 76, child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReminder(BuildContext context, QuickFlowEntry entry) {
    final token = gameState.quickFlowToken(entry);
    final targets = gameState.quickFlowTargets(entry, gameCharacters);
    final active = gameState.isQuickFlowEntryActive(entry, gameCharacters);
    return _frame(
      entry: entry,
      active: active,
      complete: gameState.isQuickFlowEntryCompleted(entry, gameCharacters),
      onTap: widget.readOnly
          ? null
          : () => gameState.activateQuickFlowEntry(entry, gameCharacters),
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
    final canSelect = entry.step.selection != null;
    return _frame(
      entry: entry,
      complete: gameState.isQuickFlowEntryCompleted(entry, gameCharacters),
      onTap: !widget.readOnly && canSelect
          ? () async {
              await gameState.activateQuickFlowEntry(entry, gameCharacters);
              if (!context.mounted) return;
              _openCharacterSelection(context, entry);
            }
          : null,
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

  Widget _buildRoleChange(BuildContext context, QuickFlowEntry entry) {
    final characters = Provider.of<CharacterService>(context);
    final riot = entry.step.targetRoleId == 'riot';
    final targets = riot
        ? gameCharacters.where(
            (character) => character.fraction.name == 'minion').toList()
        : [
            if (gameState.quickFlowTarget(
                QuickFlowEntry(
                  owner: entry.owner,
                  phase: entry.phase,
                  step: entry.owner.quickFlow.stepsFor(entry.phase)
                      .firstWhere((step) => step.id == 'newFarmerPlayer'),
                ),
                gameCharacters) case final target?)
              target,
          ];
    final prerequisites = riot || gameState.isQuickFlowEntryCompleted(
        QuickFlowEntry(
          owner: entry.owner,
          phase: entry.phase,
          step: entry.owner.quickFlow.stepsFor(entry.phase)
              .firstWhere((step) => step.id == 'showNewFarmer'),
        ), gameCharacters);
    final ready = targets.isNotEmpty && prerequisites;
    return _frame(
      entry: entry,
      complete: gameState.isQuickFlowEntryCompleted(entry, gameCharacters),
      onTap: widget.readOnly || !ready
          ? null
          : () async {
              await showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(riot
                      ? 'Night 3: Minions become Riot'
                      : 'Confirm new Farmer'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (riot)
                        const Text(
                            'Wake each Minion, show YOU ARE + Riot and confirm their new character.'),
                      for (final target in targets)
                        ListTile(
                          key: ValueKey('convert-role-${target.id}'),
                          title: Text(target.playerName.isNotEmpty
                              ? target.playerName : target.name),
                          subtitle: Text('${target.name} → ${entry.step.targetRoleId}'),
                          trailing: const Icon(Icons.check_circle_outline),
                          onTap: () async {
                            if (riot) {
                              final riotRole = characters.allCharacters
                                  .firstWhere((role) => role.roleId == 'riot');
                              // The Minion sees the actual YOU ARE + Riot
                              // reveal before the Storyteller confirms it.
                              await Navigator.of(dialogContext).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ThisCharacterSelectedYouScreen(
                                    preparedInfo: QuickFlowInfo(
                                      kind: 'youAre',
                                      owner: entry.owner,
                                      recipient: target,
                                      selectedCharacter: riotRole,
                                      infoToken: Basictoken.you_are,
                                    ),
                                  ),
                                ),
                              );
                              if (!dialogContext.mounted) return;
                            }
                            final confirm = await showDialog<bool>(
                              context: dialogContext,
                              builder: (confirmContext) => AlertDialog(
                                title: const Text('Charakterwechsel bestätigen?'),
                                content: Text(
                                    '${target.playerName}: ${target.name} → ${entry.step.targetRoleId}'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(confirmContext, false),
                                    child: const Text('Abbrechen'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(confirmContext, true),
                                    child: const Text('Umwandeln'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            final ok = await gameState.applyQuickFlowRoleChange(
                                entry, target, characters);
                            if (dialogContext.mounted && ok) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.change_circle, color: Colors.white, size: 34),
          Text(
            riot ? 'Riot ${targets.length} left' : 'Farmer',
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
          onConfirm: (character) async {
            final selected =
                await gameState.setQuickFlowSelectedCharacter(entry, character);
            if (selected) {
              await gameState.completeQuickFlowEntry(entry, gameCharacters);
            }
          },
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
    final skipped = gameState.isQuickFlowInfoSkipped(entry);
    final recipient = gameState.quickFlowInfoRecipient(entry, gameCharacters);
    return _frame(
      entry: entry,
      complete: gameState.isQuickFlowEntryCompleted(entry, gameCharacters),
      onTap: !widget.readOnly && ready && !skipped
          ? () async {
              await gameState.activateQuickFlowEntry(entry, gameCharacters);
              if (!context.mounted) return;
              await _openInfo(context, entry);
            }
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            skipped
                ? Icons.visibility_off_outlined
                : gameState.quickFlowInfoNeedsConfirmation(entry)
                    ? Icons.visibility_outlined
                    : Icons.visibility,
            color: ready || skipped ? Colors.white : Colors.white38,
            size: 38,
          ),
          Text(
            recipient?.playerName.isNotEmpty == true
                ? recipient!.playerName
                : recipient?.name ?? entry.owner.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ready || skipped ? Colors.white : Colors.white38,
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
      final decision = await showDialog<_QuickFlowInfoDecision>(
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
              onPressed: () =>
                  Navigator.pop(dialogContext, _QuickFlowInfoDecision.cancel),
              child: Text(localized.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _QuickFlowInfoDecision.skip),
              child: Text(localized.skipQuickFlowAction),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _QuickFlowInfoDecision.show),
              child: Text(localized.yesContinue),
            ),
          ],
        ),
      );
      if (decision == _QuickFlowInfoDecision.skip) {
        await gameState.skipQuickFlowInfo(entry);
        await gameState.completeQuickFlowEntry(entry, gameCharacters);
        return;
      }
      if (decision != _QuickFlowInfoDecision.show) return;
      await gameState.confirmQuickFlowInfo(entry);
      if (!context.mounted) return;
    }
    final info =
        gameState.buildQuickFlowInfo(entry, gameCharacters, allCharacters);
    if (info == null || !context.mounted) return;
    // The info event is recorded only when the prepared screen is actually
    // opened. The service de-duplicates already confirmed showInfo steps.
    await gameState.confirmQuickFlowInfo(entry);
    if (!context.mounted) return;
    await gameState.completeQuickFlowEntry(entry, gameCharacters);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ThisCharacterSelectedYouScreen(preparedInfo: info),
      ),
    );
  }
}
