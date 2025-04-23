import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/components/savant_generator.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/screens/add_character_while_playing.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:blood_on_the_clocktower/screens/this-character-slected-you/this_character_selected_you_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SpielbereichScreen extends StatefulWidget {
  @override
  _SpielbereichScreenState createState() => _SpielbereichScreenState();
}

class _SpielbereichScreenState extends State<SpielbereichScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<CharacterCircleComponentState> _characterCircleKey2 =
      GlobalKey<CharacterCircleComponentState>();
  bool _isMenuVisible = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameStateService =
          Provider.of<GameStateService>(context, listen: false);
      gameStateService.closeMenu();
    });
  }

  void _toggleMenu() {
    setState(() {
      _isMenuVisible = !_isMenuVisible;
      if (_isMenuVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _resetOrderOfLayout() {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    setState(() {
      gameStateService.toggleForceUpdateLayout();
    });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        gameStateService.toggleForceUpdateLayout();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final characterService = Provider.of<CharacterService>(context);
    final gameStateService = Provider.of<GameStateService>(context);
    gameStateService.initUnusedGameTokens(characterService.gameCharacters);
    var localizedStrings = AppLocalizations.of(context)!;

    return WillPopScope(
      onWillPop: () async {
        // Bestätigungsdialog bevor man zurück navigiert
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
            title: Text(localizedStrings.toHomeScreen,
                style: TextStyle(color: Colors.white)),
            content: Text(localizedStrings.backToHomeScreenText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizedStrings.cancel,
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                    (Route<dynamic> route) => false,
                  )
                },
                child: Text(localizedStrings.backToHomeScreen,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                      'assets/images/backgrounds/background_grim_middel.jpg'),
                  // Path to your background image
                  fit: BoxFit
                      .cover, // Ensures the image covers the entire background
                ),
              ),
            ),
            // Die Charakter-Widgets
            CharacterCircleComponent(
                key: _characterCircleKey2,
                characters: characterService.gameCharactersWithoutDrunk,
                charactersForToken: characterService.gameCharacters),
            // Das Menü in der Bildschirmmitte

            Padding(
              padding: const EdgeInsets.only(top: 200, bottom: 200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (gameStateService.gameIsRunning()) ...[
                        IconButton(
                          onPressed: () => {
                            setState(() {
                              gameStateService.nextNightState(
                                  characterService.gameCharacters);
                            }),
                          },
                          icon: const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 50),
                        ),
                      ],
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: _toggleMenu,
                            child: AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _animation.value * pi / 4,
                                  child: child,
                                );
                              },
                              child: const Icon(
                                Icons.apps,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (gameStateService.showNightStateHelpButton()) ...[
                        IconButton(
                          onPressed: () => _showHelpDialogBox(context),
                          icon: const Icon(Icons.help_outline,
                              color: Colors.white, size: 50),
                        ),
                      ],
                      if (gameStateService.isDawn()) ...[
                        IconButton(
                          onPressed: () => _showHelpDialogBox(context),
                          icon: const Icon(Icons.sunny,
                              color: Colors.white, size: 50),
                        ),
                      ],
                      if (gameStateService.isDust()) ...[
                        IconButton(
                          onPressed: () => _showHelpDialogBox(context),
                          icon: const Icon(Icons.mode_night,
                              color: Colors.white, size: 50),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),

            if (_isMenuVisible) ...[
              _buildMenuButton(CustomIcons.collection, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ThisCharacterSelectedYouScreen()),
                );
                _toggleMenu();
              }, const Alignment(0.02, -0.17), false, false, context),
              _buildMenuButton(Icons.person_add, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddCharacterWhilePlaying()),
                );
                _toggleMenu();
              }, const Alignment(0.3, -0.07), false, false, context),
              _buildMenuButton(Icons.arrow_back, () {
                setState(() {
                  gameStateService
                      .previousNightState(characterService.gameCharacters);
                });
                // _toggleMenu();
              }, const Alignment(-0.3, -0.07), false, false, context),
              _buildMenuButton(Icons.restore, () {
                _resetOrderOfLayout();
                _toggleMenu();
              }, const Alignment(0.3, 0.08), false, true, context),
              _buildMenuButton(Icons.close, () {
                gameStateService.endGame();
                characterService.endGame();
                _toggleMenu();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                  (Route<dynamic> route) => false,
                );
              }, const Alignment(0.02, 0.18), false, true, context),
              _buildMenuButton(CustomIcons.law, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RulesSelectionScreen()),
                );
                _toggleMenu();
              }, const Alignment(-0.3, 0.08), false, false, context),
            ],
            _buildUnassingedTokens(context),
            _buildSavantGeneratorButton(context, characterService)
          ],
        ),
      ),
    );
  }

  void _showHelpDialogBox(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final chracterService = Provider.of<CharacterService>(context);
        final gameStateService = Provider.of<GameStateService>(context);
        var awakeCharacter =
            gameStateService.getAwakeCharacter(chracterService.gameCharacters);
        return AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
          title: Text(gameStateService.getNightStanteHelpTitle(awakeCharacter),
              style: const TextStyle(color: Colors.white)),
          content: Text(gameStateService.getNightStateHelpText(awakeCharacter),
              style: const TextStyle(color: Colors.white)),
        );
      },
    );
  }

  Widget _buildUnassingedTokens(BuildContext context) {
    final gameStateService = Provider.of<GameStateService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final characterService = Provider.of<CharacterService>(context);
    return Positioned(
        bottom: 4,
        right: 4,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var token in gameStateService
                    .getUnassignedSetupTokens(characterService.gameCharacters))
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF493131),
                    ),
                    child: Padding(
                        padding: EdgeInsets.all(
                            settingsService.tokenKnobSize * 0.11),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: settingsService.tokenKnobSize,
                              height: settingsService.tokenKnobSize * 0.6,
                              alignment: Alignment.center,
                              child: CircleAvatar(
                                radius: settingsService.tokenKnobSize,
                                backgroundImage: AssetImage(
                                    'assets/images/characters/${token.image}.png'),
                                backgroundColor: const Color(0xFF493131),
                              ),
                            ),
                            SizedBox(
                              width: settingsService.tokenKnobSize * 0.8,
                              child: AutoSizeText(
                                token.name,
                                textAlign: TextAlign.center,
                                minFontSize: 4,
                                maxFontSize: 12,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            // Ein kleiner Abstand zwischen Bild und Text

                            const SizedBox(height: 2),
                          ],
                        )),
                  ),
              ],
            ),
          ],
        ));
  }

  Widget _buildSavantGeneratorButton(
      BuildContext context, CharacterService characterService) {
    // Überprüfe, ob das Array ein Charakter mit dem Icon "Icon_savant" enthält
    bool hasSavantIcon =
        characterService.gameCharactersWithoutDrunk.any((character) {
      return character.image ==
          'Icon_savant'; // Oder die entsprechende Logik, um das Icon zu finden
    });

    // Wenn es einen Charakter mit dem "Icon_savant" gibt, den Button anzeigen
    if (hasSavantIcon) {
      return Align(
        alignment: Alignment.bottomRight, // Unten rechts positionieren
        child: IconButton(
          icon: Image.asset(
            'assets/images/characters/Icon_savant.png', // Beispielbild
            width: 40, // Breite des Bildes
            height: 40, // Höhe des Bildes
          ),
          onPressed: () {
            // Popup-Fenster öffnen
            showDialog(
              context: context,
              builder: (BuildContext context) => const SavantGenerator(),
            );
          },
        ),
      );
    }

    // Wenn kein Charakter mit dem Icon vorhanden ist, nichts anzeigen
    return SizedBox.shrink();
  }

  // Funktion zum Erstellen der Menü-Buttons
  Widget _buildMenuButton(
      IconData icon,
      VoidCallback onPressed,
      Alignment alignment,
      bool disabled,
      bool showConfirmDialog,
      BuildContext context) {
    var closeDialog = icon == Icons.close;
    var localizedStrings = AppLocalizations.of(context)!;
    return Align(
      alignment: alignment,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!disabled) {
              if (showConfirmDialog) {
                // Zeige den Bestätigungsdialog an
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
                      title: Text(
                          closeDialog
                              ? localizedStrings.endGame
                              : localizedStrings.layoutReset,
                          style: const TextStyle(color: Colors.white)),
                      content: Text(
                          closeDialog
                              ? localizedStrings.reallyEndGame
                              : localizedStrings.reallyResetLayout,
                          style: const TextStyle(color: Colors.white)),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Dialog schließen
                          },
                          child: Text(localizedStrings.cancel,
                              style: TextStyle(color: Colors.white)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Dialog schließen
                            onPressed(); // Die tatsächliche Aktion ausführen
                          },
                          child: Text(
                              closeDialog
                                  ? localizedStrings.yesEndGame
                                  : localizedStrings.yesResetLayout,
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    );
                  },
                );
              } else {
                // Führe die Aktion sofort aus, wenn kein Dialog gezeigt werden soll
                onPressed();
              }
            }
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4a3b5e),
            ),
            child: Icon(icon, color: disabled ? Colors.grey : Colors.white),
          ),
        ),
      ),
    );
  }
}
