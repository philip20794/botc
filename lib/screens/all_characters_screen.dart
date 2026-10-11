import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class AllCharactersScreen extends StatefulWidget {
  bool hideTravellers = true;
  AllCharactersScreen({Key? key}) : super(key: key);

  _AllCharactersScreenState createState() => _AllCharactersScreenState();
}

class _AllCharactersScreenState extends State<AllCharactersScreen> {
  @override
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    final scriptService = Provider.of<ScriptService>(context);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);

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

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              final maxSelectorWidth =
                  (constraints.maxWidth - 84).clamp(112.0, 240.0).toDouble();
              final scriptWidth = (constraints.maxWidth * 0.55)
                  .clamp(112.0, maxSelectorWidth)
                  .toDouble();
              return Row(
                children: [
                  Expanded(
                    child: AutoSizeText(
                      localizedStrings.allCharactersOf,
                      minFontSize: 8,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Card(
                    margin: EdgeInsets.zero,
                    color: const Color(0xFF4a3b5e),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: SelectGameset(
                        disabled: false,
                        scriptWidth: scriptWidth,
                        showManagementAction: false,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
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
      ),
    );
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
