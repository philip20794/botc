import 'dart:math';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';

class SavantGenerator extends StatefulWidget {
  const SavantGenerator({Key? key}) : super(key: key);

  @override
  State<SavantGenerator> createState() => _SavantGeneratorState();
}

class _SavantGeneratorState extends State<SavantGenerator> {
  String test = '';

  List<String> onlineList = [
    "[Character] was selected by the [Minion] last night.",
    "At least [Number] player's ability/abilities did not work correctly last night.",
    "[Character] and [Character] are seated next to each other.",
    "There was no starting demon.",
    "No one is affected by the madness ability today.",
    "At least [Number] number of dead players are evil.",
    "Good players woke last night.",
    "The death(s) last night were not due to a demon choice.",
    "All townsfolk information received last night was correct.",
    "A player changed character last night.",
    "[Number] players do not know their real role.",
    "A poisoned townsfolk got true information last night.",
    "[Demon] is not in play.",
    "[Character] is in play OR [character] is in play.",
    "A once per game ability has/hasn't been used.",
    "[Character] is not in play.",
    "There are more/less outsiders/townsfolk than when the game started.",
    "The outsider count has/has not been modified.",
    "A once per game ability has received false information.",
    "The demon is sitting next to [Number] townsfolk.",
    "The demon targeted a dead player last night.",
    "The Snake Charmer selected [Character/Role Type] last night.",
    "Two people claiming the same role are on the same team.",
    "Exactly [Number] townsfolk targeted an evil player/the demon last night.",
    "Your (alive) neighbors are the same/different alignments.",
    "You had a private conversation with an evil player yesterday.",
    "[Character] started as good, but is now evil.",
    "One of your neighbors has [Number] reminder tokens on them.",
    "Last night, a player declined to use their ability.",
    "A Chef would have gotten a [Number] last night.",
    "At least [Number] of your (alive) neighbors are drunk or poisoned.",
    "The longest contiguous chain of good/evil players is [Number].",
    "[Number] players received a number last night.",
    "A good/evil player is affected by the madness ability today.",
    "There are no madness-related characters in this game.",
    "An Evil Player/Outsider was nominated yesterday.",
    "At least [Number] player is affected by madness.",
    "The Lunatic and Demon chose different targets last night.",
    "The demon is next to minion/outsider.",
    "[Character] is a demon bluff.",
    "[Character] nominated yesterday.",
    "No new characters were created last night.",
    "[Number] once-per-game abilities have been used.",
    "No outsiders voted yesterday.",
    "[Player] and [Player] are the same alignment.",
    "The total number of Townsfolk pairs is [Number].",
    "It is impossible for the demon to change to another player.",
    "[Player] died in the night, but not by a demon ability.",
    "A player changed alignment last night.",
    "[Number] evil players woke last night.",
    "[Number] of your neighbors was selected by another player.",
    "[Minion] has chosen the same player every night.",
    "An evil player chose themself last night.",
    "The [Character] received sober, healthy, and true information last night/yesterday.",
    "There are at least [Number] roles that prevent death.",
    "All evil players are still alive.",
    "At least one minion did not know who the demon was at the start of the game.",
    "You are witch cursed.",
    "A sober Noble would have seen [Player], [Player], and [Player].",
    "[Number] of your neighbors is poisoned.",
    "A once-per-game ability was not triggered successfully.",
    "The [Minion] and Demon are not seated next to each other.",
    "At least [Number] players received incorrect information last night.",
    "[Character] did not wake last night.",
    "The demon's ability failed last night.",
    "[Character] is poisoned.",
    "Two Players targeted the same player last night.",
    "[Number] players are seated between the demon and the [Minion].",
    "An evil Player is pretending to be a [Role Type].",
    "A player who voted yesterday is poisoned.",
    "[Number] players received an incorrect number yesterday.",
    "The demon chose to kill a dead Player during the game.",
  ];

  @override
  void initState() {
    super.initState();
  }

  void getRandomText() {
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    Gameset selectedGameset = gameStateService.gameset;
    List<Character> allCharactersOfGameset = characterService.allCharacters
        .where((element) => element.gameset.contains(selectedGameset))
        .toList();

    List<Character> allButTrevelors = allCharactersOfGameset
        .where((character) => [
              Fraction.townsfolk,
              Fraction.outsider,
              Fraction.demon,
              Fraction.minion
            ].contains(character.fraction))
        .toList();

    List<Character> demons = allCharactersOfGameset
        .where((chracter) => chracter.fraction == Fraction.demon)
        .toList();
    List<Character> minions = allCharactersOfGameset
        .where((chracter) => chracter.fraction == Fraction.minion)
        .toList();
    setState(() {
      String text = onlineList[Random().nextInt(onlineList.length)];

      for (int i = 0; i <= 3; i++) {
        // Ersetze [Character] mit zufälligen Charakteren
        text = text.replaceFirst('[Character]',
            allButTrevelors[Random().nextInt(allButTrevelors.length)].name);
        text = text.replaceFirst('[character]',
            allButTrevelors[Random().nextInt(allButTrevelors.length)].name);
      }

      // Ersetze [Role Type] mit zufälligen Rollentypen
      text = text.replaceAll('[Role Type]',
          ['Townsfolk', 'Outsider', 'Demon', 'Minion'][Random().nextInt(4)]);

      text = text.replaceAll('[Character/Role Type]',
          ['Townsfolk', 'Outsider', 'Demon', 'Minion'][Random().nextInt(4)]);

      // Ersetze [Number] mit einer zufälligen Zahl zwischen 1 und 3
      text = text.replaceAll('[Number]', (Random().nextInt(3) + 1).toString());

      // Ersetze [Player] mit einem zufälligen Spielernamen
      for (int i = 0; i <= 3; i++) {
        text = text.replaceFirst(
            '[Player]',
            gameStateService.playerNames[
                Random().nextInt(gameStateService.playerNames.length)]);
      }

      for (int i = 0; i <= 3; i++) {
        // Ersetze [Demon] und [Minion] aus den Charakteren mit entsprechender Fraktion
        text = text.replaceFirst(
            '[Demon]', demons[Random().nextInt(demons.length)].name);
        text = text.replaceFirst(
            '[Minion]', minions[Random().nextInt(minions.length)].name);
      }

      // Speichere den bearbeiteten Text
      test = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    getRandomText();
    return GestureDetector(
      onTap: () {
        getRandomText();
      },
      child: Dialog(
        backgroundColor: const Color(0xFF282c34),
        child: SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    test,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
