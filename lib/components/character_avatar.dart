import 'package:blood_on_the_clocktower/components/half_circle_clipper.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CharacterAvatar extends StatefulWidget {
  final Character character;
  final bool showIsSelected;
  final double size;
  final bool showName;
  final Color? selectionBorderColor;
  final bool forSelectCharacter;
  final bool isSelected;
  final bool showNightHighlightDuringSelection;
  final bool isBluff;
  final bool showExemplare;

  CharacterAvatar({
    required this.character,
    required this.showIsSelected,
    required this.size,
    required this.showName,
    this.selectionBorderColor,
    this.isSelected = false,
    this.showNightHighlightDuringSelection = false,
    this.isBluff = false,
    this.forSelectCharacter = false,
    this.showExemplare = false,
  });

  @override
  _CharacterAvatarState createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar> {
  @override
  Widget build(BuildContext context) {
    // Chronicle target selection uses a different selection color. Preserve
    // the current night actor's white ring independently of those targets:
    // the two indicators convey different information and can coexist.
    final nightHighlightDuringSelection =
        widget.showIsSelected && widget.showNightHighlightDuringSelection
            ? context.select<GameStateService, bool>((service) =>
                service.nightCount > 0 &&
                service.isCharacterHighlighted(widget.character))
            : false;
    final bool isSelected;
    if (!widget.showIsSelected) {
      isSelected = false;
    } else if (widget.forSelectCharacter) {
      isSelected = widget.isSelected;
    } else {
      final nightCount = context
          .select<GameStateService, int>((service) => service.nightCount);
      isSelected = nightCount > 0
          ? context.select<GameStateService, bool>(
              (service) => service.isCharacterHighlighted(widget.character))
          : context.select<CharacterService, bool>((service) => service
              .containsCharacter(service.gameCharacters, widget.character));
    }

    return RepaintBoundary(
      child: Transform(
          alignment: Alignment.center, // Drehpunkt des Stacks
          transform:
              Matrix4.rotationZ(widget.character.upsideDown ? 3.14159 : 0),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(0),
                child: Stack(
                  key: const ValueKey('character-avatar-artwork-stack'),
                  children: [
                    Positioned(
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: AssetImage(
                                'assets/images/backgrounds/token.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Unterstes Bild
                    Positioned(
                        top: -widget.size * 0.1,
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(
                                  roleImageAssetPath(widget.character.image)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )),
                    // The selection ring must be ABOVE the role artwork.
                    // It used to be painted on the background token, then
                    // partly obscured by some large/circular role icons.
                    // This applies to every role (and bluff/selection views),
                    // not just the Fortune Teller.
                    if (widget.showIsSelected &&
                        (isSelected || widget.isBluff))
                      Positioned(
                        left: nightHighlightDuringSelection ? 6 : 0,
                        top: nightHighlightDuringSelection ? 6 : 0,
                        child: IgnorePointer(
                          child: Container(
                            key: const ValueKey(
                                'character-avatar-highlight-outline'),
                            width: widget.size -
                                (nightHighlightDuringSelection ? 12 : 0),
                            height: widget.size -
                                (nightHighlightDuringSelection ? 12 : 0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isBluff
                                    ? Colors.redAccent
                                    : widget.selectionBorderColor ??
                                        Colors.white,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // White = actor currently awake. Gold = Chronicle target.
                    // Draw white on the outside of the gold ring so selecting
                    // the active actor as a target cannot mask its night ring.
                    if (nightHighlightDuringSelection)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: Container(
                            key: const ValueKey(
                                'character-avatar-night-highlight-outline'),
                            width: widget.size,
                            height: widget.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.showName)
                Positioned(
                  bottom: widget.size < 150
                      ? -widget.size * 0.05
                      : widget.size * 0.2,
                  left: widget.size * 0.15,
                  child: Container(
                    width: widget.size * 0.7,
                    height: 40,
                    alignment: Alignment.center,
                    child: HalfCircleTextWidget(
                      text: widget.character.name,
                      size: widget.size,
                    ),
                  ),
                ),
              if (widget.showExemplare)
                Positioned(
                  top: widget.size * 0.05,
                  right: widget.size * 0.05,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4a3b5e),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.character.numberOfExemplars}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.size * 0.1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          )),
    );
  }
}
