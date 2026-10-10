import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(localizedStrings.addCharacter,
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              alignment: Alignment.bottomCenter,
              image: AssetImage(
                  'assets/images/backgrounds/background_grim_top.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/backgrounds/background_grim_middel.jpg'), // Path to your background image
                fit: BoxFit
                    .cover, // Ensures the image covers the entire background
              ),
            ),
          ),
          Row(
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
        ],
      ),
    );
  }

  Container _buildTextInputFiled(BuildContext context) {
    var showErrorHint = playerAllreadyExists();
    var maxWhidth = MediaQuery.of(context).size.width;
    var localizedStrings = AppLocalizations.of(context)!;
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    var disable = characterService.addCharacterToGameWithFractionFabled ||
        (character != null && character?.fraction == Fraction.fabled);
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
    return Container(
      alignment: Alignment.center,
      color: Color(0xFF4a3b5e),
      child: ToggleButtons(
        fillColor: Color(0xFF6f678a),
        children: [
          _buildFractionAvatar(context, Fraction.townsfolk),
          _buildFractionAvatar(context, Fraction.outsider),
          _buildFractionAvatar(context, Fraction.minion),
          _buildFractionAvatar(context, Fraction.demon),
          _buildFractionAvatar(context, Fraction.traveller),
          _buildFractionAvatar(context, Fraction.fabled),
        ],
        isSelected: [
          characterService.addCharacterToGameWithFractionTownsfolk,
          characterService.addCharacterToGameWithFractionOutsider,
          characterService.addCharacterToGameWithFractionMinion,
          characterService.addCharacterToGameWithFractionDemon,
          characterService.addCharacterToGameWithFractionTraveller,
          characterService.addCharacterToGameWithFractionFabled,
        ],
        onPressed: (int index) {
          setState(() {
            characterService.setAllAddCharacterToGameWithFractionToFalse();
            switch (index) {
              case 0:
                characterService.addCharacterToGameWithFractionTownsfolk = true;
                break;
              case 1:
                characterService.addCharacterToGameWithFractionOutsider = true;
                break;
              case 2:
                characterService.addCharacterToGameWithFractionMinion = true;
                break;
              case 3:
                characterService.addCharacterToGameWithFractionDemon = true;
                break;
              case 4:
                characterService.addCharacterToGameWithFractionTraveller = true;
                break;
              case 5:
                characterService.addCharacterToGameWithFractionFabled = true;
                break;
            }
          });
        },
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
                    character.fraction != Fraction.fabled) {
                  character.playerName = playerName;
                  gameStatusService.addPlayerName(playerName);
                }
                characterService.addCharacter(character);
                Navigator.pop(context);
              },
              child:
                  playerName.isNotEmpty && character.fraction != Fraction.fabled
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

  CircleAvatar _buildFractionAvatar(BuildContext context, Fraction fraction) {
    final maxWidth = MediaQuery.of(context).size.width;
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    Character character;
    switch (fraction) {
      case Fraction.townsfolk:
        character = characterService.getCharacterByImage('Icon_undertaker');
        break;
      case Fraction.outsider:
        character = characterService.getCharacterByImage('Icon_sweetheart');
        break;
      case Fraction.minion:
        character = characterService.getCharacterByImage('Icon_pithag');
        break;
      case Fraction.demon:
        character = characterService.getCharacterByImage('Icon_shabaloth');
        break;
      case Fraction.traveller:
        character = characterService.getCharacterByImage('Icon_bonecollector');
        break;
      case Fraction.fabled:
        character = characterService.getCharacterByImage('Icon_buddhist');
        break;
    }
    return CircleAvatar(
      radius: maxWidth / 12 - 6,
      backgroundColor: Colors.transparent,
      backgroundImage:
          AssetImage('assets/images/characters/${character.image}.png'),
    );
  }

  void _showChangeCharacterDialog(
      BuildContext context, Function(Character) onCharacterSelected) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameCharacters = characterService.gameCharactersBackupWithoutDrunk;
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    Gameset selectedGameset = gameStateService.gameset;
    List<Character> allCharactersOfGameset = characterService.allCharacters
        .where((element) => element.gameset.contains(selectedGameset))
        .toList();

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
    } else if (characterService.addCharacterToGameWithFractionFabled) {
      charactersToChooseFrom = characterService.allCharacters
          .where((element) => element.fraction == Fraction.fabled)
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
                    backgroundImage: AssetImage(
                        'assets/images/characters/${newCharacter.image}.png'),
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
