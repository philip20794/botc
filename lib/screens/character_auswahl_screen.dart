import 'dart:math';

import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/screens/show_characters_to_players.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class CharacterAuswahlScreen extends StatefulWidget {
  final bool hideTravellers;
  final bool hideFabled;

  CharacterAuswahlScreen({
    Key? key,
    this.hideTravellers = true,
    this.hideFabled = true,
  }) : super(key: key);

  _CharacterAuswahlScreenState createState() => _CharacterAuswahlScreenState();
}

class _CharacterAuswahlScreenState extends State<CharacterAuswahlScreen> {
  int randomOneOrZero = 1;
  int randomMinusOrPlusOne = 1;
  int randomTwoOrZero = 2;
  int randomZeroToThree = 2;
  bool? _lastSyncedSelectionDone;

  void setPlayerName() {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    characterService.syncPlayerNames(gameStateService.playerNames);
  }

  void _shuffleCharacters() {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    if (gameStateService.gameIsRunning()) {
      return;
    }
    gameStateService.reset(characterService.gameCharactersBackup);
    characterService.shuffelCharacters();
    setPlayerName();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameStateService =
          Provider.of<GameStateService>(context, listen: false);
      gameStateService.closeMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    var localizedStrings = AppLocalizations.of(context)!;
    final scriptService = Provider.of<ScriptService>(context);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);

    Fraction getFractionWithMaxDistanceToMaxCount() {
      var fractionWithMaxDistanceToMaxCount = Fraction.townsfolk;
      var currentMaxDistanceToMaxCount = 0;

      final counts = <Fraction, int>{};
      for (var character in characterService.gameCharacters) {
        counts[character.fraction] = (counts[character.fraction] ?? 0) + 1;
      }

      for (var fraction in Fraction.values) {
        if (fraction == Fraction.traveller ||
            fraction == Fraction.fabled ||
            fraction == Fraction.loric) {
          continue;
        }
        var maxCounts = getMaxCount(context, fraction);

        var currentCount = counts[fraction] ?? 0;
        var distanceToMaxCount = maxCounts - currentCount;

        if (distanceToMaxCount > currentMaxDistanceToMaxCount) {
          currentMaxDistanceToMaxCount = distanceToMaxCount;
          fractionWithMaxDistanceToMaxCount = fraction;
        }
      }
      return fractionWithMaxDistanceToMaxCount;
    }

    // Methode zur Zählung der Fraktionen
    Map<Fraction, int> getFractionCounts() {
      final counts = <Fraction, int>{};
      for (var character in characterService.gameCharacters) {
        counts[character.fraction] = (counts[character.fraction] ?? 0) + 1;
      }

      var travelersInGame = characterService.gameCharacters
          .where((element) => element.fraction == Fraction.traveller)
          .toList();

      for (var index = 0; index < travelersInGame.length; index++) {
        var fractionWithMaxDistance = getFractionWithMaxDistanceToMaxCount();
        counts[fractionWithMaxDistance] =
            (counts[fractionWithMaxDistance] ?? 0) + 1;
      }

      return counts;
    }

    final selectedCharacterCounts = getFractionCounts();
    final characterSelectionDone = done(context, selectedCharacterCounts);
    final regularPlayerCount = gameStateService.playerNames.length -
        characterService.gameCharacters
            .where((character) => character.fraction == Fraction.traveller)
            .length;
    final requiredBluffCount =
        gameStateService.requiredDemonBluffCount(regularPlayerCount);
    final bluffsComplete =
        gameStateService.hasRequiredDemonBluffs(regularPlayerCount);
    final selectionDone = characterSelectionDone && bluffsComplete;
    final validationMessages = <String>[
      if (requiredBluffCount > 0 && !bluffsComplete)
        localizedStrings.demonBluffsMissing(
          gameStateService.demonBluffRoleIds.length,
          requiredBluffCount,
        ),
      if (requiredBluffCount == 0 &&
          gameStateService.demonBluffRoleIds.isNotEmpty)
        localizedStrings.demonBluffsNotUsed,
    ];
    if (_lastSyncedSelectionDone != selectionDone) {
      _lastSyncedSelectionDone = selectionDone;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          gameStateService.setChracterSelectionDone(selectionDone);
        }
      });
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizedStrings.characterSelection,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Center(
                child: IconButton(
                    onPressed: () => _getRandomCharacters(getFractionCounts()),
                    icon: const Icon(Icons.shuffle, color: Colors.white)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Center(
                child: Text(
                  '${characterService.gameCharacters.length}/${gameStateService.playerNames.length}',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4), // Höhe der Fraktionszeile
            child: Container(
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFractionText(
                      context, Fraction.townsfolk, selectedCharacterCounts),
                  _buildFractionText(
                      context, Fraction.outsider, selectedCharacterCounts),
                  _buildFractionText(
                      context, Fraction.minion, selectedCharacterCounts),
                  _buildFractionText(
                      context, Fraction.demon, selectedCharacterCounts),
                ],
              ),
            ),
          ),
        ),
        body: SelectCharacterComponent(
          charactersToChooseFrom: allCharactersOfGameset,
          onConfirm: () {
            gameStateService.setChracterSelectionDone(true);
            if (gameStateService.nightCount > -1) {
              return;
            } else {
              _shuffleCharacters();
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ShowCharactersToPlayers()),
            );
          },
          title: localizedStrings.characterSelection,
          confirmButtonText: localizedStrings.showCharactersToPlayers,
          confirmButtonIcon: Icons.remove_red_eye,
          travellersAreSelectable: true,
          fabledAreSelectable: true,
          isForSetupGame: true,
          forSetupIsDone: selectionDone,
          validationMessages: validationMessages,
          blockConfirmWhenDisabled: !bluffsComplete,
          demonBluffsEnabled: requiredBluffCount > 0,
          showBackground: false,
        ),
      ),
    );
  }

  // Widget zum Erstellen des Fraktions-Textes
  Widget _buildFractionText(
      BuildContext context, Fraction fraction, Map<Fraction, int> counts) {
    final count = counts[fraction] ?? 0;
    String label;
    final int maxCount = getMaxCount(context, fraction);

    switch (fraction) {
      case Fraction.townsfolk:
        label = 'Townsfolk';
        break;
      case Fraction.outsider:
        label = 'Outsider';
        break;
      case Fraction.minion:
        label = 'Minion';
        break;
      case Fraction.demon:
        label = 'Demon';
        break;
      case Fraction.traveller:
        label = 'Traveller';
        break;
      case Fraction.fabled:
        label = 'Fabled';
        break;
      case Fraction.loric:
        label = 'Loric';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Text(
            '$count/$maxCount $label',
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  bool done(BuildContext context, Map<Fraction, int> counts) {
    var allDone = true;
    for (var fraction in Fraction.values) {
      if (fraction == Fraction.traveller ||
          fraction == Fraction.fabled ||
          fraction == Fraction.loric) {
        continue;
      }
      final count = counts[fraction] ?? 0;
      var minNumberOfCharacters = getMaxCount(context, fraction);
      if (count != minNumberOfCharacters) {
        allDone = false;
        break;
      }
    }
    return allDone;
  }

  int changeNumberOfFraction(Fraction fraction, int currentValue) {
    final CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    final GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_baron')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue -= 2;
        case Fraction.outsider:
          currentValue += 2;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_drunk')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += 1;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_fanggu')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue -= 1;
        case Fraction.outsider:
          currentValue += 1;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_godfather')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue -= randomMinusOrPlusOne;
        case Fraction.outsider:
          currentValue += randomMinusOrPlusOne;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
            .any((character) => character.image == 'Icon_vigormortis') &&
        ([6, 8, 9, 11, 12, 14].contains(gameStateService.playerNames.length) ||
            gameStateService.playerNames.length > 14)) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += 1;
        case Fraction.outsider:
          currentValue -= 1;
        default:
          break;
      }
    }
    // Experimentals
    var normalNrOfMinions = 1;
    if (gameStateService.playerNames.length >= 13) {
      normalNrOfMinions = 3;
    } else if (gameStateService.playerNames.length >= 10) {
      normalNrOfMinions = 2;
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_legion')) {
      var demon = (gameStateService.playerNames.length * 0.7).round();
      var town = gameStateService.playerNames.length - demon;
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue = town;
        case Fraction.outsider:
          currentValue = 0;
        case Fraction.minion:
          currentValue = 0;
        case Fraction.demon:
          currentValue = demon;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_riot')) {
      switch (fraction) {
        case Fraction.minion:
          currentValue = 0;
        case Fraction.demon:
          currentValue += normalNrOfMinions;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_balloonist')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue -= randomOneOrZero;
        case Fraction.outsider:
          currentValue += randomOneOrZero;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_marionette')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += normalNrOfMinions - 1;
        case Fraction.minion:
          currentValue = 1;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_summoner')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += 1;
        case Fraction.demon:
          currentValue = 0;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_xaan')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue -= randomZeroToThree;
        case Fraction.outsider:
          currentValue += randomZeroToThree;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_kazali')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += normalNrOfMinions;
        case Fraction.minion:
          currentValue = 0;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_lilmonsta')) {
      switch (fraction) {
        case Fraction.minion:
          currentValue += 1;
        case Fraction.demon:
          currentValue = 0;
        default:
          break;
      }
    }
    if (characterService.gameCharacters
        .any((character) => character.image == 'Icon_lordoftyphon')) {
      switch (fraction) {
        case Fraction.townsfolk:
          currentValue += normalNrOfMinions - 1;
        case Fraction.outsider:
          currentValue += 1;
        case Fraction.minion:
          currentValue = 0;
        default:
          break;
      }
    }
    return currentValue;
  }

  int getMaxCount(BuildContext context, Fraction fraction) {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    if (gameStateService.playerNames.length < 5) {
      return 0;
    }
    switch (gameStateService.playerNames.length) {
      case 5:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 3);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 0);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 6:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 3);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 7:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 5);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 0);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 8:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 5);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 9:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 5);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 10:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 7);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 0);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 11:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 7);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 12:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 7);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 13:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 9);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 0);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 3);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      case 14:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 9);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 1);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 3);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
      default:
        switch (fraction) {
          case Fraction.townsfolk:
            return changeNumberOfFraction(fraction, 9);
          case Fraction.outsider:
            return changeNumberOfFraction(fraction, 2);
          case Fraction.minion:
            return changeNumberOfFraction(fraction, 3);
          case Fraction.demon:
            return changeNumberOfFraction(fraction, 1);
          default:
            return -1;
        }
    }
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

  Future<void> _getRandomCharacters(Map<Fraction, int> counts) async {
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);
    final previousRoleIds = characterService.gameCharacters
        .map((character) => character.roleId)
        .toList();
    final previousBluffs = gameStateService.demonBluffRoleIds;
    characterService.clearGameCards();
    var done = false;
    _addRandomCharacterOfFraction(Fraction.demon);
    randomOneOrZero = Random().nextInt(2);
    randomMinusOrPlusOne = Random().nextBool() ? 1 : -1;
    randomTwoOrZero = Random().nextBool() ? 2 : 0;
    randomZeroToThree = Random().nextInt(4);
    while (!done) {
      if (isFractionNotDone(Fraction.minion)) {
        _addRandomCharacterOfFraction(Fraction.minion);
      } else if (isFractionNotDone(Fraction.outsider)) {
        _addRandomCharacterOfFraction(Fraction.outsider);
      } else if (isFractionNotDone(Fraction.townsfolk)) {
        _addRandomCharacterOfFraction(Fraction.townsfolk);
      } else {
        done = true;
      }
    }
    final regularPlayerCount = gameStateService.playerNames.length -
        characterService.gameCharacters
            .where((character) => character.fraction == Fraction.traveller)
            .length;
    if (gameStateService.requiredDemonBluffCount(regularPlayerCount) == 0) {
      await gameStateService.clearDemonBluffs();
      return;
    }

    final selectedRoleIds = characterService.gameCharacters
        .map((character) => character.roleId)
        .toSet();
    final availableBluffs = allCharactersOfGameset
        .where((character) =>
            (character.fraction == Fraction.townsfolk ||
                character.fraction == Fraction.outsider) &&
            !selectedRoleIds.contains(character.roleId))
        .toList();
    if (availableBluffs.length < 3) {
      characterService.clearGameCards();
      for (final roleId in previousRoleIds) {
        Character? previousCharacter;
        for (final character in allCharactersOfGameset) {
          if (character.roleId == roleId) {
            previousCharacter = character;
            break;
          }
        }
        if (previousCharacter != null) {
          characterService.addCharacter(previousCharacter);
        }
      }
      await gameStateService.setDemonBluffRoleIds(previousBluffs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.notEnoughBluffs)),
      );
      return;
    }
    availableBluffs.shuffle();
    await gameStateService.setDemonBluffRoleIds(
      availableBluffs.take(3).map((character) => character.roleId),
    );
  }

  bool isFractionNotDone(Fraction fraction) {
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    return getMaxCount(context, fraction) >
        characterService.getFractionCount(fraction);
  }

  void _addRandomCharacterOfFraction(Fraction fraction) {
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);
    List<Character> charactersOfFraction = allCharactersOfGameset
        .where((character) => character.fraction == fraction)
        .toList();
    List<Character> availableCharacters = charactersOfFraction
        .where(
            (character) => !characterService.gameCharacters.contains(character))
        .toList();
    if (availableCharacters.isNotEmpty) {
      Character randomCharacter =
          availableCharacters[Random().nextInt(availableCharacters.length)];
      characterService.addCharacter(randomCharacter);
      if (randomCharacter.image == 'Icon_choirboy') {
        characterService
            .addCharacter(characterService.getCharacterByImage('Icon_king'));
      }
      if (randomCharacter.image == 'Icon_huntsman') {
        characterService
            .addCharacter(characterService.getCharacterByImage('Icon_damsel'));
      }
    }
  }
}
