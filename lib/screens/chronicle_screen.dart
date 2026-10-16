import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/chronicle_form_dialog.dart';
import 'package:blood_on_the_clocktower/components/chronicle_visual_tiles.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/models/chronicle_summary.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChronicleScreen extends StatelessWidget {
  final bool archived;

  const ChronicleScreen({super.key, this.archived = false});

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    final service = context.watch<ChronicleService>();
    final log = archived ? service.lastChronicle : service.activeChronicle;
    final events = [...?log?.events]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final summaries = const ChronicleSummaryProjector()
        .project(events)
        .where((entry) => !(log?.hiddenSummaryIds.contains(entry.id) ?? false))
        .toList(growable: false);
    final sections = _sections(summaries);

    return AppBackground(
      type: archived ? AppBackgroundType.ui : AppBackgroundType.playground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(archived ? localized.lastChronicle : localized.chronicle),
        ),
        body: SafeArea(
          top: false,
          child: summaries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      localized.chronicleEmpty,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 17),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: sections.length,
                  itemBuilder: (context, index) =>
                      _buildSection(context, sections[index], log),
                ),
        ),
      ),
    );
  }

  List<_ChronicleSection> _sections(List<ChronicleSummaryEntry> entries) {
    final result = <_ChronicleSection>[];
    for (final entry in entries) {
      final key = '${entry.phase.name}:${entry.round}';
      final section = result.where((item) => item.key == key).firstOrNull;
      if (section == null) {
        result.add(_ChronicleSection(
          key,
          entry.phase,
          entry.round,
          [entry],
        ));
      } else {
        section.entries.add(entry);
      }
    }
    return result;
  }

  Widget _buildSection(
    BuildContext context,
    _ChronicleSection section,
    ChronicleLog? log,
  ) {
    final localized = AppLocalizations.of(context)!;
    final title = switch (section.phase) {
      ChroniclePhase.setup => localized.chronicleSetup,
      ChroniclePhase.night => localized.chronicleNight(section.round),
      ChroniclePhase.day => localized.chronicleDay(section.round),
    };
    final accent = section.phase == ChroniclePhase.night
        ? const Color(0xFF7E9EEB)
        : const Color(0xFFD4AF67);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.fromLTRB(17, 10, 0, 0),
            decoration: BoxDecoration(
              border: Border(
                left:
                    BorderSide(color: accent.withValues(alpha: 0.55), width: 2),
              ),
            ),
            child: Column(
              children: [
                for (final entry in section.entries)
                  _buildSummaryCard(context, entry, log),
                if (section.phase == ChroniclePhase.night)
                  _optionalEventButton(
                    context,
                    section.round,
                    log,
                    excludedCharacterIds: section.entries
                        .map((entry) => entry.actor.characterId)
                        .toSet(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _savantStatementText(ChronicleEvent event) {
    final statement = event.details['statement'];
    if (statement is! Map) return '';
    return statement['rendered'] as String? ??
        statement['template'] as String? ??
        '';
  }

  Widget _buildSummaryCard(
    BuildContext context,
    ChronicleSummaryEntry summary,
    ChronicleLog? log,
  ) {
    final lifeEvent = summary.events.length == 1 &&
            summary.events.single.type == ChronicleEventType.lifeStatusChanged
        ? summary.events.single
        : null;
    if (lifeEvent != null) {
      return _buildLifeStatusCard(context, summary, lifeEvent);
    }
    final savantEvents = summary.events
        .where((event) => event.type == ChronicleEventType.savantStatement)
        .toList();
    if (savantEvents.isNotEmpty &&
        savantEvents.length == summary.events.length) {
      return Card(
        key: ValueKey('savant-chronicle-${summary.id}'),
        margin: const EdgeInsets.only(bottom: 10),
        color: const Color(0xFF21192F).withValues(alpha: 0.9),
        child: ListTile(
          leading: const Icon(Icons.auto_stories, color: Color(0xFFD4AF67)),
          title: Text('Savant (${savantEvents.length})'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < savantEvents.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${index + 1}. ${_savantStatementText(savantEvents[index])}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final resultGroups = _resultGroups(context, summary, log);
    final pending = summary.events
        .where((event) => event.type == ChronicleEventType.nightInformation)
        .any((event) {
      final definition = event.inputDefinition;
      final entries = event.informationEntries;
      if (definition == null || entries.isEmpty) return true;
      return entries.any((entry) {
        final values = entry['values'] is Map
            ? Map<String, dynamic>.from(entry['values'] as Map)
            : const <String, dynamic>{};
        return !_definitionIsComplete(definition, values);
      });
    });
    final card = Card(
      key: ValueKey('chronicle-summary-${summary.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: pending
          ? const Color(0xFF3D3152).withValues(alpha: 0.82)
          : const Color(0xFF21192F).withValues(alpha: 0.9),
      shape: _cardShape(pending),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChronicleTokenTile.actor(snapshot: summary.actor),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFFE1C583),
                size: 26,
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: resultGroups.isEmpty
                    ? const [ChronicleEmptyResultTile()]
                    : resultGroups,
              ),
            ),
          ],
        ),
      ),
    );
    return _dismissibleCard(context, summary, card);
  }

  Widget _dismissibleCard(
    BuildContext context,
    ChronicleSummaryEntry summary,
    Widget card,
  ) {
    return Dismissible(
      key: ValueKey('chronicle-summary-dismiss-${summary.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.55},
      background: GestureDetector(
        onTap: () => _removeSummary(context, summary),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(left: 24),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFF7A2638),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.delete_outline, color: Colors.white, size: 28),
        ),
      ),
      onDismissed: (_) => _removeSummary(context, summary),
      child: card,
    );
  }

  Widget _buildLifeStatusCard(
    BuildContext context,
    ChronicleSummaryEntry summary,
    ChronicleEvent event,
  ) {
    final alive = event.details['alive'] == true;
    final accent = alive ? const Color(0xFFD4AF67) : const Color(0xFFC94B59);
    final title = alive
        ? AppLocalizations.of(context)!.chronicleRevivedTitle
        : AppLocalizations.of(context)!.chronicleDeadTitle;
    final card = Card(
      key: ValueKey('chronicle-summary-${summary.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF21192F).withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.82), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            Row(
              children: [
                ChronicleTokenTile.player(snapshot: summary.actor),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFFE1C583),
                    size: 26,
                  ),
                ),
                Expanded(
                  child: alive
                      ? Icon(
                          Icons.wb_sunny_rounded,
                          color: accent,
                          size: 46,
                        )
                      : _TombstoneIcon(color: accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return _dismissibleCard(context, summary, card);
  }

  Future<void> _removeSummary(
    BuildContext context,
    ChronicleSummaryEntry summary,
  ) async {
    final service = Provider.of<ChronicleService>(context, listen: false);
    await service.hideSummary(summary.id, archived: archived);
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(strings.chronicleEntryRemoved),
          action: SnackBarAction(
            label: strings.undo,
            onPressed: () =>
                service.restoreSummary(summary.id, archived: archived),
          ),
        ),
      );
  }

  List<Widget> _resultGroups(
    BuildContext context,
    ChronicleSummaryEntry summary,
    ChronicleLog? log,
  ) {
    final result = <Widget>[
      ..._quickFlowResults(context, summary, log),
    ];
    for (final event in summary.events.where(
      (event) =>
          event.type == ChronicleEventType.nightInformation &&
          event.inputDefinition != null,
    )) {
      final definition = event.inputDefinition!;
      final entries = event.informationEntries;
      if (entries.isEmpty) {
        result.add(ChronicleAddTile(
          actionKey: ValueKey('chronicle-add-${definition.id}'),
          label: definition.label,
          onTap: () => _editEntry(context, event, null, log),
        ));
        continue;
      }
      for (final entry in entries) {
        final values = entry['values'] is Map
            ? Map<String, dynamic>.from(entry['values'] as Map)
            : const <String, dynamic>{};
        final tiles = _definitionTiles(context, definition, values);
        result.add(InkWell(
          onTap: () => _editEntry(context, event, entry, log),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Wrap(spacing: 6, runSpacing: 6, children: tiles),
          ),
        ));
      }
      if (definition.repeatable) {
        result.add(ChronicleAddTile(
          actionKey: ValueKey('chronicle-repeat-${definition.id}'),
          label: definition.label,
          onTap: () => _editEntry(context, event, null, log),
        ));
      }
    }
    final existingDefinitionIds = summary.events
        .where((event) => event.type == ChronicleEventType.nightInformation)
        .map((event) => event.inputDefinition?.id)
        .whereType<String>()
        .toSet();
    final characterService = context.read<CharacterService>();
    final optionalDefinitions = context
        .read<ChronicleService>()
        .optionalDefinitions(
          round: summary.round,
          catalog: characterService.allCharacters,
          archived: archived,
        )
        .where(
          (option) =>
              option.character.characterId == summary.actor.characterId &&
              !existingDefinitionIds.contains(option.definition.id),
        );
    for (final option in optionalDefinitions) {
      result.add(ChronicleAddTile(
        actionKey: ValueKey('chronicle-add-${option.definition.id}'),
        label: option.definition.label,
        onTap: () => _addOptionalEntry(context, option, summary.round, log),
      ));
    }
    return result;
  }

  List<Widget> _definitionTiles(
    BuildContext context,
    ChronicleInputDefinition definition,
    Map<String, dynamic> values,
  ) {
    if (definition.type == ChronicleInputType.form) {
      return definition.fields
          .expand((field) => _definitionTiles(context, field, values))
          .toList(growable: false);
    }
    final value = values[definition.id];
    if (value == null) {
      if ((definition.type == ChronicleInputType.players ||
              definition.type == ChronicleInputType.characters) &&
          definition.effectiveMinCount == 0) {
        return const [];
      }
      return [
        ChronicleAddTile(label: definition.label, onTap: null),
      ];
    }
    final localized = AppLocalizations.of(context)!;
    return switch (definition.type) {
      ChronicleInputType.number => [
          ChronicleNumberTile(value: value.toString()),
        ],
      ChronicleInputType.yesNo => [
          ChronicleYesNoTile(
            value: value == true,
            yesLabel: localized.chronicleAnswerYes,
            noLabel: localized.chronicleAnswerNo,
          ),
        ],
      ChronicleInputType.player =>
        _snapshotTiles(value, players: true, multiple: false),
      ChronicleInputType.players =>
        _snapshotTiles(value, players: true, multiple: true),
      ChronicleInputType.character =>
        _snapshotTiles(value, players: false, multiple: false),
      ChronicleInputType.characters =>
        _snapshotTiles(value, players: false, multiple: true),
      ChronicleInputType.choice => [
          ChronicleTextTile(
            value: definition.options
                    .where((option) => option.value == value)
                    .map((option) => option.label)
                    .firstOrNull ??
                value.toString(),
          ),
        ],
      ChronicleInputType.text => [
          ChronicleTextTile(value: value.toString()),
        ],
      ChronicleInputType.form => const [],
    };
  }

  bool _definitionIsComplete(
    ChronicleInputDefinition definition,
    Map<String, dynamic> values,
  ) {
    if (definition.type == ChronicleInputType.form) {
      return definition.fields
          .every((field) => _definitionIsComplete(field, values));
    }
    final value = values[definition.id];
    if (definition.type == ChronicleInputType.players ||
        definition.type == ChronicleInputType.characters) {
      final count = value is List ? value.length : 0;
      return count >= definition.effectiveMinCount &&
          (definition.effectiveMaxCount == null ||
              count <= definition.effectiveMaxCount!);
    }
    return value != null;
  }

  List<Widget> _snapshotTiles(
    dynamic value, {
    required bool players,
    required bool multiple,
  }) {
    final rawValues = multiple
        ? (value is List ? value : const [])
        : [if (value is Map) value];
    return rawValues.whereType<Map>().map((raw) {
      final snapshot = ChronicleCharacterSnapshot.fromJson(
        Map<String, dynamic>.from(raw),
      );
      return players
          ? ChronicleTokenTile.player(snapshot: snapshot)
          : ChronicleTokenTile.character(snapshot: snapshot);
    }).toList(growable: false);
  }

  List<Widget> _quickFlowResults(
    BuildContext context,
    ChronicleSummaryEntry summary,
    ChronicleLog? log,
  ) {
    if (log == null) return const [];
    final service = context.read<CharacterService>();
    final actorCharacter = service.allCharacters
        .where((character) => character.roleId == summary.actor.roleId)
        .firstOrNull;
    if (actorCharacter == null) return const [];
    final phase = summary.round == 1
        ? QuickFlowPhase.firstNight
        : QuickFlowPhase.otherNights;
    final phaseSteps = actorCharacter.quickFlow.stepsFor(phase);
    final presentationSteps = phaseSteps
        .where((step) => step.type == QuickFlowStepType.showInfo)
        .toList(growable: false);
    // A showInfo step can describe an optional follow-up (for example the
    // Imp's new-Demon handoff). Its requirements are not the complete night
    // action, so never let them hide independent reminder selections such as
    // the Imp's DEAD target.
    final stepIds = phaseSteps
        .where((step) => step.type != QuickFlowStepType.showInfo)
        .map((step) => step.id)
        .toList();
    for (final step in presentationSteps) {
      stepIds.addAll(step.requires);
      final presentation = step.presentation;
      if (presentation != null) {
        stepIds.addAll(presentation.playerSteps);
        if (presentation.playerStep != null) {
          stepIds.add(presentation.playerStep!);
        }
        if (presentation.characterStep != null) {
          stepIds.add(presentation.characterStep!);
        }
      }
    }

    final result = <Widget>[];
    for (final stepId in stepIds.toSet()) {
      final candidates = log.events.where((event) {
        if (event.type == ChronicleEventType.reminderAssigned) {
          final owner = event.details['quickFlowOwner'];
          if (owner is! Map ||
              owner['characterId'] != summary.actor.characterId ||
              event.details['quickFlowStepId'] != stepId) {
            return false;
          }
          return event.round == summary.round ||
              (summary.round == 1 && event.phase == ChroniclePhase.setup);
        }
        return event.type == ChronicleEventType.quickFlowCharacterSelected &&
            event.character?.characterId == summary.actor.characterId &&
            event.round == summary.round &&
            event.details['stepId'] == stepId;
      }).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (candidates.isEmpty) continue;
      final step = [...actorCharacter.quickFlow.setup, ...phaseSteps]
          .where((item) => item.id == stepId)
          .firstOrNull;
      final snapshots = candidates
          .where((event) => event.details['snapshot'] == true)
          .toList(growable: false);
      final eventsToDisplay = snapshots.isNotEmpty ? snapshots : candidates;
      final visibleEvents = step?.operation == QuickFlowReminderOperation.append
          ? eventsToDisplay
          : [eventsToDisplay.last];
      for (final event in visibleEvents) {
        if (event.type == ChronicleEventType.reminderAssigned &&
            event.character != null) {
          result.add(ChronicleTokenTile.player(snapshot: event.character!));
        } else if (event.targets.isNotEmpty) {
          result
              .add(ChronicleTokenTile.character(snapshot: event.targets.first));
        }
      }
    }
    return result;
  }

  Widget _optionalEventButton(
    BuildContext context,
    int round,
    ChronicleLog? log, {
    Set<String> excludedCharacterIds = const {},
  }) {
    final service = context.watch<ChronicleService>();
    final characters = context.watch<CharacterService>();
    final options = service
        .optionalDefinitions(
          round: round,
          catalog: characters.allCharacters,
          archived: archived,
        )
        .where(
          (option) =>
              !excludedCharacterIds.contains(option.character.characterId),
        )
        .toList(growable: false);
    if (options.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: ValueKey('chronicle-add-optional-$round'),
        onPressed: () => _chooseOptionalEvent(context, options, round, log),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.chronicleAddOptionalEvent),
      ),
    );
  }

  Future<void> _chooseOptionalEvent(
    BuildContext context,
    List<ChronicleOptionalDefinition> options,
    int round,
    ChronicleLog? log,
  ) async {
    final selected = await showModalBottomSheet<ChronicleOptionalDefinition>(
      context: context,
      backgroundColor: const Color(0xFF332644),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context)!.chronicleAddOptionalEvent,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final option in options)
              ListTile(
                leading: _snapshotAvatar(option.character),
                title: Text(option.character.roleName),
                subtitle: Text(option.definition.label),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await _addOptionalEntry(context, selected, round, log);
  }

  Future<void> _addOptionalEntry(
    BuildContext context,
    ChronicleOptionalDefinition selected,
    int round,
    ChronicleLog? log,
  ) async {
    final event = await context.read<ChronicleService>().addOptionalInformation(
          character: selected.character,
          definition: selected.definition,
          round: round,
          archived: archived,
        );
    if (event != null && context.mounted) {
      await _editEntry(context, event, null, log);
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    ChronicleEvent event,
    Map<String, dynamic>? entry,
    ChronicleLog? log,
  ) async {
    final definition = event.inputDefinition;
    if (definition == null) return;
    final values = entry?['values'] is Map
        ? Map<String, dynamic>.from(entry!['values'] as Map)
        : <String, dynamic>{};
    final characterService = context.read<CharacterService>();
    final players = _playerChoices(log, characterService, event.round);
    final roleChoices = _characterChoices(characterService.allCharacters);
    final result = await showDialog<ChronicleFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChronicleFormDialog(
        definition: definition,
        initialValues: values,
        players: players,
        characters: roleChoices,
        canDelete: entry != null,
      ),
    );
    if (result == null || !context.mounted) return;
    final service = context.read<ChronicleService>();
    final entryId = entry?['entryId'] as String?;
    if (result.delete && entryId != null) {
      await service.deleteInformationEntry(
        eventId: event.id,
        entryId: entryId,
        archived: archived,
      );
      return;
    }
    await service.saveInformationEntry(
      eventId: event.id,
      entryId: entryId,
      values: result.values,
      targets: _playerTargets(definition, result.values),
      archived: archived,
    );
  }

  List<ChronicleCharacterSnapshot> _playerChoices(
    ChronicleLog? log,
    CharacterService service,
    int round,
  ) {
    final started = log?.events
        .where((event) => event.type == ChronicleEventType.gameStarted)
        .firstOrNull;
    if (started != null) {
      final roster = [...started.targets];
      for (final event in log!.events.where(
        (event) =>
            event.type == ChronicleEventType.characterChanged &&
            event.round <= round &&
            event.character != null &&
            event.targets.isNotEmpty,
      )) {
        final index = roster.indexWhere(
          (snapshot) =>
              snapshot.characterId == event.character!.characterId ||
              (snapshot.playerName.isNotEmpty &&
                  snapshot.playerName == event.character!.playerName),
        );
        if (index >= 0) roster[index] = event.targets.first;
      }
      return roster;
    }
    return service.gameCharactersWithoutDrunkAndFabled
        .map(ChronicleCharacterSnapshot.fromCharacter)
        .toList(growable: false);
  }

  List<ChronicleCharacterSnapshot> _characterChoices(
    List<Character> catalog,
  ) {
    final seen = <String>{};
    return catalog
        .where((character) => seen.add(character.roleId))
        .map(ChronicleCharacterSnapshot.fromCharacter)
        .toList(growable: false);
  }

  List<ChronicleCharacterSnapshot> _playerTargets(
    ChronicleInputDefinition definition,
    Map<String, dynamic> values,
  ) {
    final targets = <ChronicleCharacterSnapshot>[];
    void collect(ChronicleInputDefinition field) {
      if (field.type == ChronicleInputType.form) {
        for (final child in field.fields) {
          collect(child);
        }
        return;
      }
      if (field.type != ChronicleInputType.player &&
          field.type != ChronicleInputType.players) {
        return;
      }
      final raw = values[field.id];
      final rawItems = raw is List ? raw : [if (raw != null) raw];
      for (final item in rawItems.whereType<Map>()) {
        final snapshot = ChronicleCharacterSnapshot.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!targets
            .any((target) => target.characterId == snapshot.characterId)) {
          targets.add(snapshot);
        }
      }
    }

    collect(definition);
    return targets;
  }

  RoundedRectangleBorder _cardShape(bool pending) => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: pending
              ? const Color(0xFFD4AF67).withValues(alpha: 0.65)
              : const Color(0xFF78669A).withValues(alpha: 0.35),
        ),
      );

  Widget _snapshotAvatar(ChronicleCharacterSnapshot character) => CircleAvatar(
        radius: 27,
        backgroundColor: const Color(0xFFB5987D),
        backgroundImage: character.image.isEmpty
            ? null
            : AssetImage(roleImageAssetPath(character.image)),
        child: character.image.isEmpty
            ? const Icon(Icons.shield_outlined, color: Colors.white)
            : null,
      );
}

class _TombstoneIcon extends StatelessWidget {
  final Color color;

  const _TombstoneIcon({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 34,
              height: 41,
              alignment: const Alignment(0, -0.2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.82),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
              ),
              child: const Text(
                '✝',
                style: TextStyle(color: Colors.white, fontSize: 19),
              ),
            ),
            Positioned(
              bottom: 2,
              child: Container(width: 42, height: 5, color: color),
            ),
          ],
        ),
      );
}

class _ChronicleSection {
  final String key;
  final ChroniclePhase phase;
  final int round;
  final List<ChronicleSummaryEntry> entries;

  _ChronicleSection(this.key, this.phase, this.round, this.entries);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
