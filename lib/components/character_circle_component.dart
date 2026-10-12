import 'package:blood_on_the_clocktower/components/character.dart';
import 'package:blood_on_the_clocktower/components/fabled_token.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
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

  CharacterCircleComponent(
      {required Key key,
      required this.characters,
      this.settingsView = false,
      this.playerView = false,
      this.selectionMode = false,
      this.selectedCharacterIds = const {},
      this.onCharacterTap,
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

    final characters = widget.characters;
    final double width = settingsService.radiusX;
    final double height = settingsService.radiusY;
    final int numCols = settingsService.startAngleDiv.toInt();
    final int numRows = (2 + (characters.length - numCols * 2) / 2).ceil();

    // Berechne die verfügbare Fläche für jedes Element
    final double availableWidth =
        width - (settingsService.characterKnobSize * numCols);
    final double availableHeight =
        height - (settingsService.characterKnobSize * numRows);

    final double itemWidth = (width - availableWidth) / numCols + width;
    final double itemHeight = (height - availableHeight) / numRows + height;

    final screenHeigth = MediaQuery.of(context).size.height;

    final addToOffSetY = (screenHeigth - itemHeight * numRows) / 2;

    var pos = 0;
    final nextPositions = <int, Offset>{};

    int top = 0;
    int bottom = numRows - 1;
    int left = 0;
    int right = numCols - 1;

    while (top <= bottom && left <= right) {
      // Schritt 3: Links von unten nach oben (linke Spalte)
      if (left <= right) {
        for (int row = bottom; row >= top; row--) {
          final double x = left * itemWidth +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetX;
          final double y = row * itemHeight +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetY +
              addToOffSetY;

          nextPositions[pos] = Offset(x, y);
          pos += 1;
        }
        left++; // Bewege den linken Rand eine Spalte nach rechts
      }

      // Schritt 4: Oben von links nach rechts (die oberste Reihe)
      for (int col = left; col <= right; col++) {
        // ÄNDERUNG: Jetzt von links nach rechts
        if (top == 0) {
          // Nur für die oberste Reihe
          final double x = col * itemWidth +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetX;
          final double y = top * itemHeight +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetY +
              addToOffSetY;

          nextPositions[pos] = Offset(x, y);
          pos += 1;
        }
      }
      top++;
      // Schritt 1: Rechts von oben nach unten (rechte Spalte)
      for (int row = top; row <= bottom; row++) {
        final double x = right * itemWidth +
            settingsService.characterKnobSize / 2 +
            settingsService.offsetX;
        final double y = row * itemHeight +
            settingsService.characterKnobSize / 2 +
            settingsService.offsetY +
            addToOffSetY;

        nextPositions[pos] = Offset(x, y);
        pos += 1;
      }
      right--; // Bewege den rechten Rand eine Spalte nach links

      // Schritt 2: Unten von links nach rechts (untere Reihe)
      if (top <= bottom) {
        for (int col = right; col >= left; col--) {
          // ÄNDERUNG: Jetzt von rechts nach links
          final double x = col * itemWidth +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetX;
          final double y = bottom * itemHeight +
              settingsService.characterKnobSize / 2 +
              settingsService.offsetY +
              addToOffSetY;

          nextPositions[pos] = Offset(x, y);
          pos += 1;
        }
        bottom--; // Bewege den unteren Rand eine Reihe nach oben
      }
    }

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
              onCharacterTap: widget.selectionMode
                  ? () => widget.onCharacterTap?.call(character)
                  : null,
              menuId: i,
              onSelect: (selectedCharacter) {
                // Handle select if needed
              },
            ),
          );
  }
}
