import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ShowCharactersToPlayers extends StatefulWidget {
  @override
  _ShowCharactersToPlayersState createState() =>
      _ShowCharactersToPlayersState();
}

class _ShowCharactersToPlayersState extends State<ShowCharactersToPlayers> {
  int currentCharacterIndex = 0;
  bool isCharacterVisible = false;
  bool isDialogVisible = true;
  bool isGameMaster = false;
  bool iCanHaveSeenMyCharacter = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    var localizedStrings = AppLocalizations.of(context)!;
    if (currentCharacterIndex >=
        characterService.gameCharactersWithoutDrunkAndFabled.length) {
      isGameMaster = true;
      gameStateService.setShowCharactersToPlayers(true);
    }

    Character? currentCharacter = isGameMaster
        ? null
        : characterService
            .gameCharactersWithoutDrunkAndFabled[currentCharacterIndex];

    return WillPopScope(
      onWillPop: () async {
        // Bestätigungsdialog bevor man zurück navigiert
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.9),
            title: Text(localizedStrings.reallyWantToGoBack,
                style: TextStyle(color: Colors.white)),
            content: Text(localizedStrings.onlyTheStorytellerMayGoBack),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizedStrings.cancel,
                    style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(localizedStrings.yesImTheStoryteller,
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.transparent),
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
            if (isDialogVisible)
              Center(
                child: buildPlayerDialog(context, currentCharacter),
              )
            else
              Stack(
                children: [
                  Center(
                    child: buildCharacterView(context, currentCharacter),
                  ),
                  if (!isGameMaster) _buildHoldToShowButton(context)
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget buildPlayerDialog(BuildContext context, Character? character) {
    var localizedStrings = AppLocalizations.of(context)!;
    String dialogText = isGameMaster
        ? localizedStrings.giveTheDeviceToTheStoryteller
        : '${localizedStrings.giveTheDeviceTo} ${character!.playerName}';
    String buttonText = isGameMaster
        ? localizedStrings.iAmTheStoryteller
        : '${localizedStrings.iAm} ${character!.playerName}';

    return AlertDialog(
      title: Text(dialogText, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF6f678a).withOpacity(0.9),
      actions: [
        TextButton(
          onPressed: () {
            if (isGameMaster) {
              setState(() {
                isDialogVisible = false;
              });
            } else {
              setState(() {
                isDialogVisible = false;
              });
            }
          },
          child: Text(buttonText, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildHoldToShowButton(BuildContext context) {
    return Stack(children: [
      Positioned(
        bottom: 25,
        right: 25,
        child: GestureDetector(
          onLongPressStart: (_) {
            setState(() {
              isCharacterVisible = true;
              iCanHaveSeenMyCharacter = true;
            });
          },
          onLongPressEnd: (_) {
            setState(() {
              isCharacterVisible = false;
            });
          },
          child: Icon(
            isCharacterVisible ? Icons.visibility_off : Icons.visibility,
            size: 50,
            color: Colors.white,
          ),
        ),
      ),
      const Positioned(
          bottom: 40,
          right: 65,
          child: RotationTransition(
              turns: AlwaysStoppedAnimation(0.1),
              child:
                  Icon(Icons.arrow_forward, size: 120, color: Colors.white))),
    ]);
  }

  Widget buildCharacterView(BuildContext context, Character? character) {
    final gameService = Provider.of<GameStateService>(context);
    final characterService = Provider.of<CharacterService>(context);
    var localizedStrings = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isGameMaster)
          Column(
            children: [
              Text(
                localizedStrings.onlyForTheStoryteller,
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  if (gameService.nightCount < 0) {
                    gameService.startNewGame(
                        characterService.gameCharactersWithoutDrunkAndFabled);
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SpielbereichScreen()),
                  );
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage(
                          'assets/images/backgrounds/token.png'), // Zweites Bild
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const CircleAvatar(
                      radius: 100,
                      backgroundColor: Colors.transparent,
                      child: Icon(
                        Icons.play_arrow,
                        size: 100,
                        color: Colors.white,
                      )),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 30,
                child: AutoSizeText(
                  localizedStrings.startGame,
                  style: TextStyle(fontSize: 16),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          )
        else
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${localizedStrings.characterOf} ${character!.playerName}',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              Stack(children: [
                GestureDetector(
                  onLongPressStart: (_) {
                    setState(() {
                      isCharacterVisible = true;
                      iCanHaveSeenMyCharacter = true;
                    });
                  },
                  onLongPressEnd: (_) {
                    setState(() {
                      isCharacterVisible = false;
                    });
                  },
                  child: isCharacterVisible
                      ? CharacterAvatar(
                          character: character,
                          showIsSelected: false,
                          showName: true,
                          size: 200)
                      : const CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 100,
                          backgroundImage:
                              AssetImage('assets/images/backgrounds/token.png'),
                          child: const Icon(
                            Icons.remove_red_eye,
                            size: 80,
                            color: Colors.black,
                          ),
                        ),
                ),
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 40,
                child: AutoSizeText(
                  isCharacterVisible
                      ? character.descriptionShort
                      : localizedStrings.pressAndHoldToSeeCharacter,
                  style: const TextStyle(fontSize: 16),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: Icon(Icons.check,
                    color: iCanHaveSeenMyCharacter
                        ? Color(0xFF4a3b5e)
                        : Color(0xFF6f678a).withOpacity(0.4)),
                label: Text(localizedStrings.iHaveSeenMyCharacter,
                    style: TextStyle(
                        color: iCanHaveSeenMyCharacter
                            ? Color(0xFF4a3b5e)
                            : Color(0xFF6f678a).withOpacity(0.4))),
                onPressed: () {
                  if (!iCanHaveSeenMyCharacter) {
                    return;
                  }
                  setState(() {
                    currentCharacterIndex++;
                    isCharacterVisible = false;
                    iCanHaveSeenMyCharacter = false;
                    isDialogVisible = true;
                    if (currentCharacterIndex >=
                        Provider.of<CharacterService>(context, listen: false)
                            .gameCharactersWithoutDrunkAndFabled
                            .length) {
                      isGameMaster = true;
                    }
                  });
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
      ],
    );
  }
}
