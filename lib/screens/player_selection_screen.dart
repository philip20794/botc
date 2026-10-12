import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A read-only board view for selecting the players of a chronicle field.
///
/// The board itself is [CharacterCircleComponent], so positions and token
/// rendering are exactly the ones used by the active game board.
class PlayerSelectionScreen extends StatefulWidget {
  final String title;
  final List<ChronicleCharacterSnapshot> choices;
  final List<ChronicleCharacterSnapshot> initial;
  final int minCount;
  final int? maxCount;

  const PlayerSelectionScreen({
    super.key,
    required this.title,
    required this.choices,
    required this.initial,
    required this.minCount,
    required this.maxCount,
  });

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  late final Set<String> _choiceIds;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _choiceIds = widget.choices.map((choice) => choice.characterId).toSet();
    _selectedIds = widget.initial
        .map((choice) => choice.characterId)
        .where(_choiceIds.contains)
        .toSet();
    final maximum = widget.maxCount;
    if (maximum != null && _selectedIds.length > maximum) {
      _selectedIds.removeAll(_selectedIds.skip(maximum).toList());
    }
  }

  bool get _isValid =>
      _selectedIds.length >= widget.minCount &&
      (widget.maxCount == null || _selectedIds.length <= widget.maxCount!);

  void _toggle(Character character) {
    if (!_choiceIds.contains(character.id)) return;
    setState(() {
      if (_selectedIds.remove(character.id)) return;
      if (widget.maxCount == 1) _selectedIds.clear();
      if (widget.maxCount == null || _selectedIds.length < widget.maxCount!) {
        _selectedIds.add(character.id);
      }
    });
  }

  List<Character> _boardCharacters(CharacterService service) {
    final boardCharacters = service.gameCharactersWithoutDrunk;
    if (boardCharacters.isNotEmpty) return boardCharacters;

    // Chronicle data can be opened after an older game has been archived. In
    // that case retain the selected players' actual instance IDs and names
    // while using the current catalog only as the immutable visual source.
    return widget.choices
        .map((choice) {
          final source = service.allCharacters
              .where((character) => character.roleId == choice.roleId)
              .firstOrNull;
          if (source == null) return null;
          final character = source.copyWith(id: choice.characterId);
          character.playerName = choice.playerName;
          return character;
        })
        .whereType<Character>()
        .toList(growable: false);
  }

  void _confirm() {
    if (!_isValid) return;
    Navigator.of(context).pop(
      widget.choices
          .where((choice) => _selectedIds.contains(choice.characterId))
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    final boardCharacters = _boardCharacters(context.watch<CharacterService>());
    final maximum = widget.maxCount;
    final count = maximum == null
        ? '${_selectedIds.length}'
        : '${_selectedIds.length} / $maximum';

    return AppBackground(
      type: AppBackgroundType.playground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            CharacterCircleComponent(
              key: const ValueKey('chronicle-player-selection-board'),
              characters: boardCharacters,
              charactersForToken: boardCharacters,
              selectionMode: true,
              selectedCharacterIds: _selectedIds,
              onCharacterTap: _toggle,
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('chronicle-player-selection-back'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              count,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('chronicle-player-selection-confirm'),
                      onPressed: _isValid ? _confirm : null,
                      child: Text(localized.save),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
