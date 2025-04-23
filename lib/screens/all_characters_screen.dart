import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AllCharactersScreen extends StatefulWidget {
  bool hideTravellers = true;
  AllCharactersScreen({Key? key}) : super(key: key);

  _AllCharactersScreenState createState() => _AllCharactersScreenState();
}

class _AllCharactersScreenState extends State<AllCharactersScreen> {
  @override
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    Gameset selectedGameset = gameStateService.gameset;
    List<Character> allCharactersOfGameset = characterService.allCharacters
        .where((element) => element.gameset.contains(selectedGameset))
        .toList();

    List<Character> townsfolk = allCharactersOfGameset
        .where((element) => element.fraction == Fraction.townsfolk)
        .toList();
    List<Character> outsider = allCharactersOfGameset
        .where((element) => element.fraction == Fraction.outsider)
        .toList();
    List<Character> minion = allCharactersOfGameset
        .where((element) => element.fraction == Fraction.minion)
        .toList();
    List<Character> demon = allCharactersOfGameset
        .where((element) => element.fraction == Fraction.demon)
        .toList();
    List<Character> travellers = allCharactersOfGameset
        .where((element) => element.fraction == Fraction.traveller)
        .toList();
    var localizedStrings = AppLocalizations.of(context)!;
    var maxWidth = MediaQuery.of(context).size.width - 140;

    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                  width: maxWidth * 0.5,
                  child: AutoSizeText(localizedStrings.allCharactersOf,
                      minFontSize: 8,
                      maxLines: 1,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              SizedBox(width: 10),
              Card(
                color: Color(0xFF4a3b5e).withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: SelectGameset(disabled: false),
                ),
              ),
            ],
          ),
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
        body: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/backgrounds/background_grim_full.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(townsfolk, "Townsfolk"),
                  const Divider(color: Colors.white, thickness: 1),
                  _buildSection(outsider, "Outsider"),
                  const Divider(color: Colors.white, thickness: 1),
                  _buildSection(minion, "Minion"),
                  const Divider(color: Colors.white, thickness: 1),
                  _buildSection(demon, "Demon"),
                  const Divider(color: Colors.white, thickness: 3),
                  _buildSection(travellers, "Travellers"),
                  Center(
                      child: Text(
                    localizedStrings.notInTheFirstNight,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  )),
                ],
              ),
            ),
          ),
        ]));
  }

  Widget _buildSection(List<Character> characters, String title) {
    var travellers = title == "Travellers";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
              onTap: () {
                if (travellers) {
                  setState(() {
                    widget.hideTravellers = !widget.hideTravellers;
                  });
                }
              },
              child: Row(
                children: [
                  if (travellers) ...[
                    Icon(
                        widget.hideTravellers
                            ? Icons.arrow_drop_down
                            : Icons.arrow_drop_up,
                        color: Colors.white),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )),
          SizedBox(height: 8), // Abstand zwischen Titel und Karten
          if (!travellers || !widget.hideTravellers) ...[
            ListView.builder(
              shrinkWrap:
                  true, // Wichtig, damit der ListView in der Column funktioniert
              physics:
                  NeverScrollableScrollPhysics(), // Scroll-Verhalten deaktivieren
              itemCount: characters.length,
              itemBuilder: (context, index) {
                return _buildCard(characters[index]);
              },
            )
          ],
        ],
      ),
    );
  }

  Widget _buildCard(Character character) {
    var maxWidth = MediaQuery.of(context).size.width - 140;
    return GestureDetector(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ShowCharacter(
                      character: character,
                      showHowToRun: false,
                      showMoreDetails: true)));
        },
        child: Card(
            color: Color(0xFF4a3b5e).withOpacity(0.9),
            child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(children: [
                  CharacterAvatar(
                      character: character,
                      size: 70,
                      showName: true,
                      showIsSelected: false),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoSizeText(
                        character.name,
                        maxLines: 1,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(
                          width: maxWidth,
                          child: AutoSizeText(
                            character.descriptionShort,
                            maxLines: 2,
                            style: TextStyle(color: Colors.white),
                          ))
                    ],
                  ),
                ]))));
  }
}
