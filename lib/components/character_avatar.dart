import 'package:blood_on_the_clocktower/components/half_circle_clipper.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CharacterAvatar extends StatefulWidget {
  final Character character;
  final bool showIsSelected;
  final double size;
  final bool showName;
  bool forSelectCharacter = false;
  bool isSelected = false;
  bool showExemplare = false;

  CharacterAvatar({
    required this.character,
    required this.showIsSelected,
    required this.size,
    required this.showName,
    this.isSelected = false,
    this.forSelectCharacter = false,
    this.showExemplare = false,
  });

  @override
  _CharacterAvatarState createState() => _CharacterAvatarState();
}

class _CharacterAvatarState extends State<CharacterAvatar> {
  @override
  Widget build(BuildContext context) {
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    CharacterService characterService = Provider.of<CharacterService>(context);

    var isSelected = widget.forSelectCharacter
        ? widget.isSelected
        : gameStateService.nightCount > 0
            ? gameStateService.isCharacterAwake(widget.character)
            : characterService.containsCharacter(
                characterService.gameCharacters, widget.character);

    return Transform(
        alignment: Alignment.center, // Drehpunkt des Stacks
        transform: Matrix4.rotationZ(widget.character.upsideDown ? 3.14159 : 0),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(0),
              child: Stack(
                children: [
                  Positioned(
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.showIsSelected && isSelected
                              ? Colors.white
                              : Colors.transparent,
                          width: 4,
                        ),
                        image: const DecorationImage(
                          image:
                              AssetImage('assets/images/backgrounds/token.png'),
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
                                'assets/images/characters/${widget.character.image}.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ))
                  // Oberstes Bild
                ],
              ),
            ),
            if (widget.showName)
              Positioned(
                bottom:
                    widget.size < 150 ? -widget.size * 0.05 : widget.size * 0.2,
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
        ));
  }
}
