import 'package:blood_on_the_clocktower/components/half_circle_clipper.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FabledToken extends StatefulWidget {
  final Character character;
  final bool settingsView;
  final bool characterSelectionView;

  FabledToken({
    required this.character,
    this.settingsView = false,
    this.characterSelectionView = false,
  });

  @override
  _FabledTokenState createState() => _FabledTokenState();
}

class _FabledTokenState extends State<FabledToken> {
  var showRemoveButton = false;

  void _removeCharacter() {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    setState(() {
      characterService.removeCharacter(widget.character);
    });
  }

  void openRemoveMenu() {
    setState(() {
      showRemoveButton = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      showRemoveButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    CharacterService characterService = Provider.of<CharacterService>(context);
    SettingsService settingsService = Provider.of<SettingsService>(context);

    final size = settingsService.tokenKnobSize * 1.75;

    return Container(
        width: size,
        height: size,
        child: GestureDetector(
            onTap: () {
              if (showRemoveButton) {
                _removeCharacter();
                return;
              } else {
                openRemoveMenu();
              }
            },
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(0),
                  child: Stack(
                    children: [
                      Positioned(
                        child: Container(
                          width: size,
                          height: size,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/backgrounds/token.png'), // Zweites Bild
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      // Unterstes Bild
                      Positioned(
                          top: -size * 0.1,
                          child: showRemoveButton
                              ? Container(
                                  width: size, // Breite und Höhe anpassen
                                  height: size,
                                  child: Icon(Icons.close, color: Colors.black))
                              : Container(
                                  width: size, // Breite und Höhe anpassen
                                  height: size,
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
                Positioned(
                  bottom: size < 150 ? -size * 0.05 : size * 0.2,
                  left: size * 0.175,
                  child: Container(
                    width: size * 0.7,
                    height: 40,
                    alignment: Alignment.center,
                    child: HalfCircleTextWidget(
                      text: widget.character.name,
                      size: size,
                    ),
                  ),
                ),
              ],
            )));
  }
}
