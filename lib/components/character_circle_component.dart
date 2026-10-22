import 'package:blood_on_the_clocktower/components/character.dart';
import 'package:blood_on_the_clocktower/components/fabled_token.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/utils/character_layout_positions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

class CharacterCircleComponent extends StatefulWidget {
  final List<Character> characters;
  final List<Character> charactersForToken;
  final bool settingsView;
  final bool playerView;
  final bool selectionMode;
  final Set<String> selectedCharacterIds;
  final ValueChanged<Character>? onCharacterTap;
  final Color? selectionBorderColor;
  final Map<String, List<Token>> previewTokensByCharacterId;

  CharacterCircleComponent(
      {required Key key,
      required this.characters,
      this.settingsView = false,
      this.playerView = false,
      this.selectionMode = false,
      this.selectedCharacterIds = const {},
      this.onCharacterTap,
      this.selectionBorderColor,
      this.previewTokensByCharacterId = const {},
      required this.charactersForToken});

  @override
  CharacterCircleComponentState createState() =>
      CharacterCircleComponentState();
}

class CharacterCircleComponentState extends State<CharacterCircleComponent> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Layout values affect the calculated positions. Register this component
    // as a listener so changes made in Layout Settings are visible at once.
    Provider.of<SettingsService>(context);
    initializeCharacterPositions();
  }

  void initializeCharacterPositions() {
    // A selection view must use the board's already persisted positions. It
    // must never recalculate or persist a second layout.
    if (widget.selectionMode) return;

    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);

    if (!widget.settingsView && !gameStateService.forceUpdateLayout) {
      return;
    }

    final nextPositions = CharacterLayoutPositions.calculate(
      count: widget.characters.length,
      boardSize: MediaQuery.sizeOf(context),
      characterSize: settingsService.characterKnobSize,
      radiusX: settingsService.radiusX,
      radiusY: settingsService.radiusY,
      startAngleDiv: settingsService.startAngleDiv,
      offsetX: settingsService.offsetX,
      offsetY: settingsService.offsetY,
    );

    characterService.setCharacterPositions(nextPositions);
  }

  @override
  Widget build(BuildContext context) {
    final characterService = Provider.of<CharacterService>(context);
    final gameStateService = Provider.of<GameStateService>(context);
    final characters = widget.characters;

    return Stack(
      children: _buildCharacterWidgets(
          characters, characterService, gameStateService),
    );
  }

  List<Widget> _buildCharacterWidgets(List<Character> characters,
      CharacterService characterService, GameStateService gameStateService) {
    final List<Widget> widgets = [];

    for (int i = 0; i < characters.length; i++) {
      var character = characters[i];
      final position = characterService.characterPositions[i] ?? Offset(0, 0);

      widgets.add(
        Positioned(
          left: position.dx,
          top: position.dy,
          child: widget.selectionMode ||
                  gameStateService.isLocked ||
                  widget.settingsView
              ? _buildCharacterWidget(context, character, i, isDragging: false)
              : Draggable<Character>(
                  data: character,
                  feedback: _buildCharacterWidget(context, character, i,
                      isDragging: true),
                  childWhenDragging: Container(),
                  onDraggableCanceled: (velocity, offset) {
                    setState(() {
                      final double width = MediaQuery.of(context).size.width;
                      final double height = MediaQuery.of(context).size.height;
                      final double dx = offset.dx.clamp(0, width - 100);
                      final double dy = offset.dy.clamp(0, height - 100);
                      characterService.setCharacterPosition(i, Offset(dx, dy));
                    });
                  },
                  child: DragTarget<Character>(
                    onAccept: (data) {
                      // Handle drop if needed
                    },
                    builder: (context, candidateData, rejectedData) {
                      return _buildCharacterWidget(
                        context,
                        character,
                        i,
                        isDragging: gameStateService.isLocked,
                      );
                    },
                  ),
                ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCharacterWidget(BuildContext context, Character character, int i,
      {bool isDragging = false}) {
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);
    return character.fraction == Fraction.fabled ||
            character.fraction == Fraction.loric
        ? FabledToken(character: character, readOnly: widget.selectionMode)
        : Container(
            width: settingsService.characterKnobSize * 1.5,
            height: settingsService.characterKnobSize * 1.5,
            child: CharacterWidget(
              character: character,
              showInfo: true,
              showLongDescription: false,
              showSelect: false,
              showCharacter: true,
              showDeadOverlay: true,
              showHowToRun: true,
              showIsSelected: !widget.settingsView,
              imageLarge: true,
              showChangeCharacter: true,
              showToggleAlive: true,
              settingsView: widget.settingsView,
              showAddToken: true,
              selectionMode: widget.selectionMode,
              selectionIsSelected:
                  widget.selectedCharacterIds.contains(character.id),
              selectionBorderColor: widget.selectionBorderColor,
              onCharacterTap: widget.selectionMode
                  ? () => widget.onCharacterTap?.call(character)
                  : null,
              previewTokens: widget.previewTokensByCharacterId[character.id],
              menuId: i,
              onSelect: (selectedCharacter) {
                // Handle select if needed
              },
            ),
          );
  }
}
