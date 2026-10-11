import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

const Map<Fraction, String> _fractionIconAssetPaths = {
  Fraction.townsfolk: 'assets/images/characters/Townsfolk.png',
  Fraction.outsider: 'assets/images/characters/Outsider.png',
  Fraction.minion: 'assets/images/characters/Minion.png',
  Fraction.demon: 'assets/images/characters/Demon.png',
  Fraction.traveller: 'assets/images/characters/Traveller.png',
  Fraction.fabled: 'assets/images/characters/Fabled.png',
  Fraction.loric: 'assets/images/characters/Loric.png',
};

class AddCharacterWhilePlaying extends StatefulWidget {
  @override
  _AddCharacterWhilePlayingState createState() =>
      _AddCharacterWhilePlayingState();
}

class _AddCharacterWhilePlayingState extends State<AddCharacterWhilePlaying> {
  final TextEditingController _nameController = TextEditingController();
  Character? character;

  bool playerAllreadyExists() {
    final gameStatusService =
        Provider.of<GameStateService>(context, listen: false);
    final playerName = _nameController.text.trim();

    return gameStatusService.playerNames.contains(playerName);
  }

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizedStrings.addCharacter,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTextInputFiled(context),
                SizedBox(height: 20),
                _buildToggleButtons(context),
                SizedBox(height: 20),
                _buildCharacterSelection(context, character,
                    (Character newCharacter) {
                  setState(() {
                    character = newCharacter;
                  });
                }),
                SizedBox(height: 20),
                _buildConfirmButton(context),
              ],
            )
          ],
        ),
      ),
    );
  }

  Container _buildTextInputFiled(BuildContext context) {
    var showErrorHint = playerAllreadyExists();
    var maxWhidth = MediaQuery.of(context).size.width;
    var localizedStrings = AppLocalizations.of(context)!;
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final selectedCharacter = character;
    var disable = characterService.addCharacterToGameWithFractionFabled ||
        characterService.addCharacterToGameWithFractionLoric ||
        (selectedCharacter != null && _isSpecialCharacter(selectedCharacter));
    return Container(
      width: maxWhidth * 0.8,
      height: 100,
      child: Stack(
        children: [
          TextField(
            enabled: !disable,
            controller: _nameController,
            cursorColor: Colors.white,
            style: TextStyle(color: disable ? Colors.grey : Colors.white),
            onChanged: (value) {
              setState(() {
                showErrorHint = playerAllreadyExists();
              });
            },
            decoration: InputDecoration(
              labelText: localizedStrings.playerName,
              labelStyle:
                  TextStyle(color: disable ? Colors.grey : Colors.white),
            ),
          ),
          if (showErrorHint)
            Positioned(
              top: 58,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red,
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Text(
                    localizedStrings.playerAlreadyExists,
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Container _buildToggleButtons(BuildContext context) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final maxWidth = MediaQuery.of(context).size.width;
    return Container(
      alignment: Alignment.center,
      color: Color(0xFF4a3b5e),
      width: maxWidth,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ToggleButtons(
          fillColor: const Color(0xFF6f678a),
          children: [
            _buildFractionAvatar(context, Fraction.townsfolk),
            _buildFractionAvatar(context, Fraction.outsider),
            _buildFractionAvatar(context, Fraction.minion),
            _buildFractionAvatar(context, Fraction.demon),
            _buildFractionAvatar(context, Fraction.traveller),
            _buildFractionAvatar(context, Fraction.fabled),
            _buildFractionAvatar(context, Fraction.loric),
          ],
          isSelected: [
            characterService.addCharacterToGameWithFractionTownsfolk,
            characterService.addCharacterToGameWithFractionOutsider,
            characterService.addCharacterToGameWithFractionMinion,
            characterService.addCharacterToGameWithFractionDemon,
            characterService.addCharacterToGameWithFractionTraveller,
            characterService.addCharacterToGameWithFractionFabled,
            characterService.addCharacterToGameWithFractionLoric,
          ],
          onPressed: (int index) {
            setState(() {
              characterService.setAllAddCharacterToGameWithFractionToFalse();
              switch (index) {
                case 0:
                  characterService.addCharacterToGameWithFractionTownsfolk =
                      true;
                  break;
                case 1:
                  characterService.addCharacterToGameWithFractionOutsider =
                      true;
                  break;
                case 2:
                  characterService.addCharacterToGameWithFractionMinion = true;
                  break;
                case 3:
                  characterService.addCharacterToGameWithFractionDemon = true;
                  break;
                case 4:
                  characterService.addCharacterToGameWithFractionTraveller =
                      true;
                  break;
                case 5:
                  characterService.addCharacterToGameWithFractionFabled = true;
                  break;
                case 6:
                  characterService.addCharacterToGameWithFractionLoric = true;
                  break;
              }
            });
          },
        ),
      ),
    );
  }

  Container _buildConfirmButton(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    final gameStatusService =
        Provider.of<GameStateService>(context, listen: false);
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final character = this.character;
    final playerName = _nameController.text.trim();

    return Container(
      child: character == null
          ? const SizedBox(height: 10)
          : ElevatedButton(
              onPressed: () {
                if (playerName.isNotEmpty &&
                    !playerAllreadyExists() &&
                    !_isSpecialCharacter(character)) {
                  character.playerName = playerName;
                  gameStatusService.addPlayerName(playerName);
                }
                characterService.addCharacter(character);
                Navigator.pop(context);
              },
              child: playerName.isNotEmpty && !_isSpecialCharacter(character)
                  ? Text(localizedStrings.addPlayerAsCharacter(
                      character.name, playerName))
                  : Text(localizedStrings.addPlayerName(character.name)),
            ),
    );
  }

  Container _buildCharacterSelection(BuildContext context, Character? character,
      Function(Character) onCharacterSelected) {
    var radius = 200.0;
    return Container(
      width: radius, // Breite des Kreises
      height: radius,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          _showChangeCharacterDialog(context, onCharacterSelected);
        },
        child: character != null
            ? Stack(
                children: [
                  CharacterAvatar(
                      character: character,
                      showIsSelected: false,
                      showName: true,
                      size: radius),
                ],
              )
            : CircleAvatar(
                radius: radius,
                backgroundColor: Color(0xFFb5987d),
                child: Icon(
                  Icons.change_circle,
                  size: 80,
                  color: Colors.white,
                )),
      ),
    );
  }

  bool _isSpecialCharacter(Character character) =>
      character.fraction == Fraction.fabled ||
      character.fraction == Fraction.loric;

  void _showSpecialCharacterDialog(
    BuildContext context,
    Fraction fraction,
    Function(Character) onCharacterSelected,
    List<Character> scriptCharacters,
  ) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final allCharacters = characterService.allCharacters
        .where((character) => character.fraction == fraction)
        .toList(growable: false);
    final scriptedCharacters = scriptCharacters
        .where((character) => character.fraction == fraction)
        .toList(growable: false);
    var showScriptCharacters = scriptedCharacters.isNotEmpty;
    final strings = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final characters =
              showScriptCharacters ? scriptedCharacters : allCharacters;
          return AlertDialog(
            backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
            title: Row(
              children: [
                Expanded(
                  child: Text(strings.chooseACharacter,
                      style: const TextStyle(color: Colors.white)),
                ),
                ToggleButtons(
                  key: ValueKey('special-character-filter-${fraction.name}'),
                  constraints:
                      const BoxConstraints(minHeight: 32, minWidth: 38),
                  borderRadius: BorderRadius.circular(8),
                  isSelected: [showScriptCharacters, !showScriptCharacters],
                  onPressed: (index) =>
                      setDialogState(() => showScriptCharacters = index == 0),
                  children: const [
                    Tooltip(
                      message: 'Script',
                      child: Icon(CustomIcons.script, color: Colors.white),
                    ),
                    Tooltip(
                      message: 'All characters',
                      child: Icon(Icons.apps, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: characters.isEmpty
                  ? const Center(
                      child: Icon(Icons.info_outline, color: Colors.white))
                  : ListView.builder(
                      itemCount: characters.length,
                      itemBuilder: (context, index) {
                        final character = characters[index];
                        return ListTile(
                          minVerticalPadding: 20,
                          leading: CircleAvatar(
                            radius: 40,
                            backgroundImage:
                                AssetImage(roleImageAssetPath(character.image)),
                            backgroundColor: Colors.transparent,
                          ),
                          title: Text(character.name,
                              style: const TextStyle(color: Colors.white)),
                          onLongPress: () => Navigator.push(
                            dialogContext,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShowCharacter(character: character),
                            ),
                          ),
                          onTap: () {
                            onCharacterSelected(character);
                            Navigator.pop(dialogContext);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.cancel,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  CircleAvatar _buildFractionAvatar(BuildContext context, Fraction fraction) {
    final maxWidth = MediaQuery.of(context).size.width;
    final imagePath = _fractionIconAssetPaths[fraction];
    return CircleAvatar(
      key: ValueKey('fractionAvatar-${fraction.name}'),
      radius: maxWidth / 12 - 6,
      backgroundColor: Colors.transparent,
      child: imagePath == null
          ? const Icon(Icons.category, color: Colors.white)
          : ClipOval(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.category, color: Colors.white),
              ),
            ),
    );
  }

  void _showChangeCharacterDialog(
      BuildContext context, Function(Character) onCharacterSelected) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameCharacters = characterService.gameCharactersBackupWithoutDrunk;
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);

    final specialFraction =
        characterService.addCharacterToGameWithFractionFabled
            ? Fraction.fabled
            : characterService.addCharacterToGameWithFractionLoric
                ? Fraction.loric
                : null;
    if (specialFraction != null) {
      _showSpecialCharacterDialog(
        context,
        specialFraction,
        onCharacterSelected,
        allCharactersOfGameset,
      );
      return;
    }

    var allCharactersOfGamesetThatAreNotInGame = allCharactersOfGameset
        .where((element) => !gameCharacters.contains(element))
        .toList();

    var charactersToChooseFrom;

    if (characterService.addCharacterToGameWithFractionTownsfolk) {
      charactersToChooseFrom = allCharactersOfGamesetThatAreNotInGame
          .where((element) => element.fraction == Fraction.townsfolk)
          .toList();
    } else if (characterService.addCharacterToGameWithFractionOutsider) {
      charactersToChooseFrom = allCharactersOfGamesetThatAreNotInGame
          .where((element) => element.fraction == Fraction.outsider)
          .toList();
    } else if (characterService.addCharacterToGameWithFractionMinion) {
      charactersToChooseFrom = allCharactersOfGamesetThatAreNotInGame
          .where((element) => element.fraction == Fraction.minion)
          .toList();
    } else if (characterService.addCharacterToGameWithFractionDemon) {
      charactersToChooseFrom = allCharactersOfGamesetThatAreNotInGame
          .where((element) => element.fraction == Fraction.demon)
          .toList();
    } else if (characterService.addCharacterToGameWithFractionTraveller) {
      charactersToChooseFrom = allCharactersOfGamesetThatAreNotInGame
          .where((element) => element.fraction == Fraction.traveller)
          .toList();
    }
    var localizedStrings = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(localizedStrings.cancel,
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          title: Text(localizedStrings.chooseACharacter,
              style: TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: charactersToChooseFrom.length,
              itemBuilder: (context, index) {
                final newCharacter = charactersToChooseFrom[index];
                return ListTile(
                  minVerticalPadding: 20,
                  onLongPress: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                ShowCharacter(character: newCharacter)));
                  },
                  leading: CircleAvatar(
                    radius: 40,
                    backgroundImage:
                        AssetImage(roleImageAssetPath(newCharacter.image)),
                    backgroundColor: Colors.transparent,
                  ),
                  title: Text(newCharacter.name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    onCharacterSelected(newCharacter);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
