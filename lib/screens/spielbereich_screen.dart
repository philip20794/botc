import 'dart:async';
import 'dart:math';

import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/components/night_chronicle_controls.dart';
import 'package:blood_on_the_clocktower/components/savant_generator.dart';
import 'package:blood_on_the_clocktower/components/quick_flow_bar.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/add_character_while_playing.dart';
import 'package:blood_on_the_clocktower/screens/chronicle_screen.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:blood_on_the_clocktower/screens/this-character-slected-you/this_character_selected_you_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class SpielbereichScreen extends StatefulWidget {
  @override
  _SpielbereichScreenState createState() => _SpielbereichScreenState();
}

class _DayTimerDisplay extends StatelessWidget {
  const _DayTimerDisplay({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4A3B5E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white54),
        ),
        child: Text(
          '$minutes:$seconds',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _SpielbereichScreenState extends State<SpielbereichScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<CharacterCircleComponentState> _characterCircleKey2 =
      GlobalKey<CharacterCircleComponentState>();
  bool _isMenuVisible = false;
  late AnimationController _controller;
  late Animation<double> _animation;
  late final Timer _dayTimer;
  String? _characterLayoutSignature;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _dayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !context.read<GameStateService>().isDay()) {
        return;
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final gameStateService =
          Provider.of<GameStateService>(context, listen: false);
      gameStateService.closeMenu();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final characterSignature = characterService.gameCharacters
        .map((character) => character.id)
        .join('|');
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    if (_characterLayoutSignature != characterSignature) {
      _characterLayoutSignature = characterSignature;
      gameStateService.initUnusedGameTokens(characterService.gameCharacters);
    }
    unawaited(
      gameStateService.synchronizeNightStep(characterService.gameCharacters),
    );
  }

  @override
  void dispose() {
    _dayTimer.cancel();
    _controller.dispose();
    super.dispose();
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
      if (!mounted) {
        return;
      }
      setState(() {
        gameStateService.toggleForceUpdateLayout();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final characterService = Provider.of<CharacterService>(context);
    final gameStateService = Provider.of<GameStateService>(context);
    var localizedStrings = AppLocalizations.of(context)!;
    final bluffCharacters = <Character>[];
    for (final roleId in gameStateService.demonBluffRoleIds) {
      for (final character in characterService.allCharacters) {
        if (character.roleId == roleId) {
          bluffCharacters.add(character);
          break;
        }
      }
    }
    final chronicleInput = gameStateService
        .activeNightChronicleInput(characterService.gameCharacters);
    final hasChroniclePlayerField = chronicleInput?.hasPlayerField ?? false;

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
      child: AppBackground(
        type: AppBackgroundType.playground,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // The bar stays below character tokens in the Stack. A token can
              // therefore still start a drag when it overlaps a reminder chip.
              if (!_isMenuVisible &&
                  gameStateService
                      .quickFlowEntries(characterService.gameCharacters)
                      .isNotEmpty)
                _buildAnchoredMenuControl(
                  const Offset(0, -70),
                  QuickFlowBar(
                    gameCharacters: characterService.gameCharacters,
                    allCharacters: characterService.allCharacters,
                    gameState: gameStateService,
                  ),
                ),
              // Die Charakter-Widgets
              CharacterCircleComponent(
                  key: _characterCircleKey2,
                  characters: characterService.gameCharactersWithoutDrunk,
                  charactersForToken: characterService.gameCharacters,
                  selectionMode: hasChroniclePlayerField,
                  selectedCharacterIds: !hasChroniclePlayerField
                      ? const {}
                      : chronicleInput!.selectedPlayerIdsForAllFields,
                  selectionBorderColor: const Color(0xFFD4AF67),
                  onCharacterTap: chronicleInput == null
                      ? null
                      : (character) => unawaited(
                            gameStateService.toggleNightChroniclePlayer(
                              chronicleInput,
                              character,
                            ),
                          )),
              // Das Menü in der Bildschirmmitte

              if (gameStateService.gameIsRunning())
                _buildAnchoredMenuControl(
                  const Offset(0, -154),
                  IconButton(
                    onPressed: () => gameStateService
                        .nextNightState(characterService.gameCharacters),
                    icon: const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 50),
                  ),
                ),
              if (bluffCharacters.isNotEmpty)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ThisCharacterSelectedYouScreen(
                              showDemonBluffsOnly: true,
                            ),
                          ),
                        ),
                        child: Semantics(
                          button: true,
                          label: localizedStrings.demonBluffs,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(localizedStrings.demonBluffs,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final character in bluffCharacters)
                                    CharacterAvatar(
                                      character: character,
                                      showIsSelected: false,
                                      size: 34,
                                      showName: false,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              _buildAnchoredMenuControl(
                Offset.zero,
                GestureDetector(
                  key: const ValueKey('playground-menu-anchor'),
                  onTap: _toggleMenu,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Transform.rotate(
                      angle: _animation.value * pi / 4,
                      child: child,
                    ),
                    child:
                        const Icon(Icons.apps, size: 60, color: Colors.white),
                  ),
                ),
              ),
              if (gameStateService.showNightStateHelpButton())
                _buildAnchoredMenuControl(
                  const Offset(0, 72),
                  GestureDetector(
                    key: const ValueKey('night-phase-info-button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showHelpDialogBox(context),
                    onLongPress: () =>
                        _showCurrentNightCharacterDetails(context),
                    child: const SizedBox(
                      width: 56,
                      height: 56,
                      child: Icon(Icons.help_outline,
                          color: Colors.white, size: 50),
                    ),
                  ),
                ),
              if (chronicleInput != null &&
                  (chronicleInput.yesNoFields.isNotEmpty ||
                      chronicleInput.numberFields.isNotEmpty))
                _buildAnchoredMenuControl(
                  const Offset(0, 122),
                  NightChronicleControls(
                    input: chronicleInput,
                    gameCharacters: characterService.gameCharacters,
                  ),
                ),
              if (gameStateService.isDawn())
                _buildAnchoredMenuControl(
                  const Offset(0, 72),
                  IconButton(
                    onPressed: () => _showHelpDialogBox(context),
                    icon:
                        const Icon(Icons.sunny, color: Colors.white, size: 50),
                  ),
                ),
              if (gameStateService.isDay())
                _buildAnchoredMenuControl(
                  const Offset(0, 72),
                  const Icon(Icons.sunny, color: Colors.white, size: 50),
                ),
              if (gameStateService.isDay())
                _buildAnchoredMenuControl(
                  const Offset(0, 126),
                  _DayTimerDisplay(elapsed: gameStateService.dayElapsed),
                ),
              if (gameStateService.isDust())
                _buildAnchoredMenuControl(
                  const Offset(0, 72),
                  IconButton(
                    onPressed: () => _showHelpDialogBox(context),
                    icon: const Icon(Icons.mode_night,
                        color: Colors.white, size: 50),
                  ),
                ),

              if (_isMenuVisible) ...[
                _buildMenuButton(Icons.menu_book, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChronicleScreen(),
                    ),
                  );
                  _toggleMenu();
                }, const Offset(0, -80), false, false, context),
                _buildMenuButton(CustomIcons.collection, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ThisCharacterSelectedYouScreen()),
                  );
                  _toggleMenu();
                }, const Offset(-62, -48), false, false, context),
                _buildMenuButton(Icons.person_add, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddCharacterWhilePlaying()),
                  );
                  _toggleMenu();
                }, const Offset(62, -48), false, false, context),
                _buildMenuButton(Icons.arrow_back, () {
                  setState(() {
                    gameStateService
                        .previousNightState(characterService.gameCharacters);
                  });
                  // _toggleMenu();
                }, const Offset(76, 12), false, false, context),
                _buildMenuButton(Icons.restore, () {
                  _resetOrderOfLayout();
                  _toggleMenu();
                }, const Offset(46, 68), false, true, context),
                _buildMenuButton(Icons.close, () async {
                  await gameStateService.endGame();
                  characterService.endGame();
                  if (!context.mounted) return;
                  _toggleMenu();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => HomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                }, const Offset(-46, 68), false, true, context),
                _buildMenuButton(CustomIcons.law, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RulesSelectionScreen()),
                  );
                  _toggleMenu();
                }, const Offset(-76, 12), false, false, context),
              ],
              _buildSavantGeneratorButton(context, characterService)
            ],
          ),
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
        final languageCode = Localizations.localeOf(context).languageCode;
        var awakeCharacter =
            gameStateService.getAwakeCharacter(chracterService.gameCharacters);
        return AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
          title: Text(
              gameStateService.getNightStanteHelpTitle(
                awakeCharacter,
                gameCharacters: chracterService.gameCharacters,
                languageCode: languageCode,
              ),
              style: const TextStyle(color: Colors.white)),
          content: Text(
              gameStateService.getNightStateHelpText(
                awakeCharacter,
                gameCharacters: chracterService.gameCharacters,
                languageCode: languageCode,
              ),
              style: const TextStyle(color: Colors.white)),
        );
      },
    );
  }

  void _showCurrentNightCharacterDetails(BuildContext context) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final awakeCharacter =
        gameStateService.getAwakeCharacter(characterService.gameCharacters);
    final roleId = awakeCharacter?.roleId;
    if (roleId == null || roleId.isEmpty) return;

    Character? localizedCharacter;
    for (final character in characterService.allCharacters) {
      if (character.roleId == roleId) {
        localizedCharacter = character;
        break;
      }
    }
    // A running game's role instance is still a safe fallback for legacy or
    // partially loaded catalogs, while the primary lookup always uses roleId.
    final character = localizedCharacter ?? awakeCharacter;
    if (character == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowCharacter(
          character: character,
          showMoreDetails: true,
        ),
      ),
    );
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
  Widget _buildAnchoredMenuControl(Offset offset, Widget child) {
    return Align(
      alignment: Alignment.center,
      child: Transform.translate(offset: offset, child: child),
    );
  }

  Widget _buildMenuButton(IconData icon, VoidCallback onPressed, Offset offset,
      bool disabled, bool showConfirmDialog, BuildContext context) {
    var closeDialog = icon == Icons.close;
    var localizedStrings = AppLocalizations.of(context)!;
    return _buildAnchoredMenuControl(
      offset,
      Material(
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
