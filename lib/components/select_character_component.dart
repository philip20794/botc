import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectCharacterComponent extends StatefulWidget {
  final List<Character> charactersToChooseFrom;
  final bool travellersAreSelectable;
  final bool fabledAreSelectable;
  final int numberOfCharactersToSelect;
  final bool isForSetupGame;
  final bool forSetupIsDone;
  final bool needToConfirm;
  final String title;
  final String confirmButtonText;
  final Function() onConfirm;
  final Function(List<Character> characters)? onResult;
  final IconData confirmButtonIcon;
  final List<String> validationMessages;
  final bool blockConfirmWhenDisabled;
  final bool demonBluffsEnabled;
  final bool showBackground;

  SelectCharacterComponent({
    required this.charactersToChooseFrom,
    required this.onConfirm,
    required this.title,
    required this.confirmButtonText,
    this.onResult,
    this.travellersAreSelectable = false,
    this.fabledAreSelectable = false,
    this.numberOfCharactersToSelect = 1,
    this.isForSetupGame = false,
    this.forSetupIsDone = false,
    this.confirmButtonIcon = Icons.remove_red_eye,
    this.needToConfirm = true,
    this.validationMessages = const [],
    this.blockConfirmWhenDisabled = false,
    this.demonBluffsEnabled = true,
    this.showBackground = true,
  });

  _SelectCharacterComponentState createState() =>
      _SelectCharacterComponentState();
}

class _SelectCharacterComponentState extends State<SelectCharacterComponent> {
  List<Character> result = [];

  void selectCharacter(Character character) {
    if (result.contains(character)) {
      result.remove(character);
    } else {
      if (result.length >= widget.numberOfCharactersToSelect) {
        result.removeAt(0);
      }
      result.add(character);
    }
  }

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    // Rebuild token borders when a persistent bluff selection changes.
    Provider.of<GameStateService>(context);

    List<Character> townsfolk = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.townsfolk)
        .toList();
    List<Character> outsider = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.outsider)
        .toList();
    List<Character> minion = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.minion)
        .toList();
    List<Character> demon = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.demon)
        .toList();
    List<Character> travellers = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.traveller)
        .toList();
    List<Character> fabled = characterService.allCharacters
        .where((element) => element.fraction == Fraction.fabled)
        .toList();

    final content = Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
              top: 8, left: 8, right: 8, bottom: widget.needToConfirm ? 64 : 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCharacterSection(context, 'Townsfolk', townsfolk, false),
                const Divider(color: Colors.white, thickness: 1),
                _buildCharacterSection(context, 'Outsider', outsider, false),
                const Divider(color: Colors.white, thickness: 1),
                _buildCharacterSection(context, 'Minion', minion, false),
                const Divider(color: Colors.white, thickness: 1),
                _buildCharacterSection(context, 'Demon', demon, false),
                if (widget.travellersAreSelectable) ...[
                  const Divider(color: Colors.white, thickness: 3),
                  _buildCharacterSection(
                      context, 'Traveller', travellers, true),
                ],
                if (widget.fabledAreSelectable) ...[
                  const Divider(color: Colors.white, thickness: 1),
                  _buildCharacterSection(context, 'Fabled', fabled, true),
                ],
              ],
            ),
          ),
        ),
        if (widget.needToConfirm) ...[
          NextScreenFooter(
            nextScreenName: widget.confirmButtonText,
            nextScreenIcon: widget.confirmButtonIcon,
            currentScreenName: widget.title,
            hideHomeButton: !widget.isForSetupGame,
            disabled: !isDone(),
            validationMessages: widget.validationMessages,
            blockNavigationWhenDisabled: widget.blockConfirmWhenDisabled,
            onTap: () {
              widget.onConfirm();
              if (widget.onResult != null) {
                widget.onResult!(result);
              }
            },
          )
        ],
      ],
    );

    return widget.showBackground ? AppBackground(child: content) : content;
  }

  Widget _buildCharacterSection(BuildContext context, String title,
      List<Character> characters, bool showHideButton) {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final settingsService = Provider.of<SettingsService>(context);
    final characterService = Provider.of<CharacterService>(context);
    bool hidden = false;
    var maxWidth = MediaQuery.of(context).size.width;

    if (title == 'Traveller') {
      hidden = settingsService.hideTravellers;
    } else if (title == 'Fabled') {
      hidden = settingsService.hideFabled;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: GestureDetector(
                onTap: () {
                  if (!showHideButton) {
                    return;
                  }
                  setState(() {
                    if (title == 'Traveller') {
                      settingsService.hideTravellers =
                          !settingsService.hideTravellers;
                    } else if (title == 'Fabled') {
                      settingsService.hideFabled = !settingsService.hideFabled;
                    }
                  });
                },
                child: Row(children: [
                  if (showHideButton) ...[
                    Icon(
                      hidden ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  if (!hidden) ...[
                    const SizedBox(width: 20),
                    ToggleButtons(
                      constraints:
                          const BoxConstraints(minHeight: 30, minWidth: 60),
                      borderRadius: BorderRadius.circular(10),
                      borderColor: const Color(0xFF4a3b5e),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFF4a3b5e),
                      isSelected: [
                        characterService.showInfoButtonOnCharacterSelection,
                        !characterService.showInfoButtonOnCharacterSelection
                      ],
                      onPressed: (int index) {
                        gameStateService.closeMenu();
                        setState(() {
                          characterService.showInfoButtonOnCharacterSelection =
                              index == 0;
                        });
                      },
                      children: const [
                        Icon(Icons.help, color: Colors.white),
                        Icon(Icons.circle_outlined, color: Colors.white),
                      ],
                    ),
                  ],
                ]))),
        if (!hidden) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // Anzahl der Spalten im Grid
              crossAxisSpacing: 0, // Abstand zwischen den Spalten
              mainAxisSpacing: 0, // Abstand zwischen den Zeilen
            ),
            itemCount:
                characters.length, // Anzahl der Charaktere in der Fraktion
            itemBuilder: (context, index) {
              Character character = characters[index];

              // Prüfen, ob der Charakter bereits ausgewählt ist
              bool isSelected = widget.isForSetupGame
                  ? characterService.containsCharacter(
                      characterService.gameCharacters, character)
                  : result.contains(character);
              final isBluff = widget.isForSetupGame &&
                  gameStateService.isDemonBluff(character.roleId);
              final isEligibleBluff = widget.demonBluffsEnabled &&
                  (character.fraction == Fraction.townsfolk ||
                      character.fraction == Fraction.outsider);

              return GestureDetector(
                  onLongPress: () {
                    if (characterService.showInfoButtonOnCharacterSelection) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ShowCharacter(character: character),
                        ),
                      );
                    } else if (widget.isForSetupGame &&
                        character.variableNumberOfExemplars &&
                        isSelected) {
                      showCharacterExemplarDialog(
                        context,
                        character.numberOfExemplars,
                        character.possibleNrOfExemplars,
                        (newValue) {
                          setState(() {
                            if (isSelected) {
                              characterService.removeCharacter(character);
                              character.numberOfExemplars = newValue;
                              characterService.addCharacter(character);
                            } else {
                              character.numberOfExemplars = newValue;
                            }
                          });
                        },
                      );
                    } else if (widget.isForSetupGame) {
                      gameStateService.toggleDemonBluff(
                        character.roleId,
                        isEligible: isEligibleBluff || isBluff,
                        isGameCharacter: isSelected,
                      );
                    }
                  },
                  onTap: () {
                    if (characterService.showInfoButtonOnCharacterSelection) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  ShowCharacter(character: character)));
                    } else if (widget.isForSetupGame) {
                      if (isBluff) {
                        return;
                      }
                      if (isSelected) {
                        characterService.removeCharacter(character);
                      } else {
                        characterService.addCharacter(character);
                      }
                      return;
                    } else {
                      setState(() {
                        selectCharacter(character);
                        if (!widget.needToConfirm) {
                          widget.onConfirm();
                          if (widget.onResult != null) {
                            widget.onResult!(result);
                          }
                        }
                      });
                    }
                  },
                  child: CharacterAvatar(
                      character: character,
                      showIsSelected: true,
                      forSelectCharacter: true,
                      isSelected: isSelected,
                      isBluff: isBluff,
                      showExemplare: widget.isForSetupGame &&
                          character.variableNumberOfExemplars,
                      size: maxWidth / 4,
                      showName: true));
            },
          ),
        ],
      ],
    );
  }

  bool isDone() {
    return widget.isForSetupGame
        ? widget.forSetupIsDone
        : result.length == widget.numberOfCharactersToSelect;
  }

  int getMenuIndex(Character character) {
    switch (character.fraction) {
      case Fraction.townsfolk:
        return 0;
      case Fraction.outsider:
        return 100;
      case Fraction.minion:
        return 1000;
      case Fraction.demon:
        return 10000;
      case Fraction.traveller:
        return 100000;
      case Fraction.fabled:
        return 1000000;
      case Fraction.loric:
        return 10000000;
    }
  }

  Future<void> showCharacterExemplarDialog(
      BuildContext context,
      int currentExemplars,
      List<int> possibleNrOfExemplars,
      Function(int) onValueChanged) {
    int updatedExemplars = currentExemplars;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
          title: const Text('Adjust Exemplars',
              style: TextStyle(color: Colors.white)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_downward, color: Colors.white),
                onPressed: () {
                  if (possibleNrOfExemplars.isNotEmpty) {
                    // Handle case with predefined values
                    int currentIndex =
                        possibleNrOfExemplars.indexOf(updatedExemplars);
                    if (currentIndex > 0) {
                      updatedExemplars =
                          possibleNrOfExemplars[currentIndex - 1];
                      onValueChanged(updatedExemplars);
                    }
                  } else {
                    // Handle case with free adjustment
                    if (updatedExemplars > 0) {
                      updatedExemplars--;
                      onValueChanged(updatedExemplars);
                    }
                  }
                },
              ),
              Text(
                updatedExemplars.toString(),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                onPressed: () {
                  if (possibleNrOfExemplars.isNotEmpty) {
                    // Handle case with predefined values
                    int currentIndex =
                        possibleNrOfExemplars.indexOf(updatedExemplars);
                    if (currentIndex >= 0 &&
                        currentIndex < possibleNrOfExemplars.length - 1) {
                      updatedExemplars =
                          possibleNrOfExemplars[currentIndex + 1];
                      onValueChanged(updatedExemplars);
                    }
                  } else {
                    // Handle case with free adjustment
                    updatedExemplars++;
                    onValueChanged(updatedExemplars);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
