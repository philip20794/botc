import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/basicToken.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/screens/select_one_charater.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class ThisCharacterSelectedYouScreen extends StatefulWidget {
  final bool showDemonBluffsOnly;
  final QuickFlowInfo? preparedInfo;

  const ThisCharacterSelectedYouScreen({
    super.key,
    this.showDemonBluffsOnly = false,
    this.preparedInfo,
  });

  @override
  _ThisCharacterSelectedYouScreenState createState() =>
      _ThisCharacterSelectedYouScreenState();
}

class _ThisCharacterSelectedYouScreenState
    extends State<ThisCharacterSelectedYouScreen> {
  Basictoken selectedToken = Basictoken.empty_string;
  Character? character;
  Character? character2;
  Character? character3;
  Character? character4;
  Character? characterToBeMadAbout;

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    if (widget.showDemonBluffsOnly) {
      return _buildDemonBluffs(context, localizedStrings);
    }
    if (widget.preparedInfo != null) {
      return _buildPreparedQuickFlow(context, localizedStrings);
    }
    var tokensWithNoAction = [
      Basictoken.this_is_the_demon,
      Basictoken.these_are_your_minions,
      Basictoken.did_you_vote_today,
      Basictoken.did_you_nominate_today,
    ];
    return Scaffold(
      appBar: AppBar(
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
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // This character selected you token

                  Container(
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      color: Color(0xFFb5987d),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: DropdownButton<Basictoken>(
                      dropdownColor: const Color(0xFF6f678a),
                      itemHeight: 100,
                      menuMaxHeight: MediaQuery.of(context).size.height * 0.8,
                      value: selectedToken,
                      underline:
                          Container(), // Entfernt die standardmäßige Unterstreichung
                      onChanged: (Basictoken? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          selectedToken = newValue;
                        });
                      },
                      items: _getDropdownItems(context, true),
                      selectedItemBuilder: (BuildContext context) {
                        return _getDropdownItems(context, false);
                      },
                    ),
                  ),

                  SizedBox(height: 16.0), // Abstand zwischen den Elementen
                  // Character Image

                  if (!tokensWithNoAction.contains(selectedToken) &&
                      selectedToken !=
                          Basictoken.these_chracters_are_not_in_play) ...[
                    _buildCharacterSelection(context, character,
                        (Character newCharacter) {
                      setState(() {
                        character = newCharacter;
                      });
                    }, true, 1),
                  ],

                  if (selectedToken ==
                      Basictoken.these_chracters_are_not_in_play) ...[
                    _buildStoredDemonBluffTokens(context, localizedStrings),
                  ],

                  if (selectedToken == Basictoken.these_are_all_outsiders) ...[
                    _buildCharacterSelection(context, character2,
                        (Character newCharacter) {
                      setState(() {
                        character2 = newCharacter;
                      });
                    }, true, 2),
                    _buildCharacterSelection(context, character3,
                        (Character newCharacter) {
                      setState(() {
                        character3 = newCharacter;
                      });
                    }, true, 3),
                    _buildCharacterSelection(context, character4,
                        (Character newCharacter) {
                      setState(() {
                        character4 = newCharacter;
                      });
                    }, true, 4),
                  ],

                  if (character?.image == 'Icon_cerenovus' &&
                      selectedToken ==
                          Basictoken.this_chracter_selected_you) ...[
                    SizedBox(height: 16.0),
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        color: Color(0xFFb5987d),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        localizedStrings.toBeMadAbout,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Container(
                      width: 250.0, // Breite des Kreises
                      height: 250.0,
                      alignment: Alignment.center,
                      child: characterToBeMadAbout != null
                          ? CircleAvatar(
                              radius: 150, // Halbe Breite als Radius
                              backgroundImage: AssetImage(
                                roleImageAssetPath(
                                    characterToBeMadAbout?.image ?? ''),
                              ),
                              backgroundColor: Color(0xFFb5987d),
                            )
                          : GestureDetector(
                              onTap: () {
                                _showChangeCharacterDialog(context,
                                    (Character newCharacter) {
                                  setState(() {
                                    characterToBeMadAbout = newCharacter;
                                  });
                                }, true);
                              },
                              child: const CircleAvatar(
                                  radius: 100,
                                  backgroundColor: Color(0xFFb5987d),
                                  child: Icon(
                                    Icons.change_circle,
                                    size: 80,
                                    color: Colors.white,
                                  )),
                            ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparedQuickFlow(
      BuildContext context, AppLocalizations localizedStrings) {
    final info = widget.preparedInfo!;
    final isCharacterSelected = info.kind.startsWith('characterSelectedYou');
    final showsPlayers = info.players.isNotEmpty ||
        const {
          'playersAndCharacter',
          'playerAndCharacter',
          'pointToPlayers',
          'characterSelectedYouMadAboutPlayer',
        }.contains(info.kind);
    final showsCharacter = const {
      'playersAndCharacter',
      'playerAndCharacter',
      'showCharacter',
      'characterSelectedYouMadAboutCharacter',
    }.contains(info.kind);
    final showsMadAbout = const {
      'characterSelectedYouMadAboutCharacter',
      'characterSelectedYouMadAboutPlayer',
    }.contains(info.kind);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/images/backgrounds/background_grim_middel.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCharacterSelected) ...[
                  _preparedLabel(localizedStrings.this_chracter_selected_you),
                  const SizedBox(height: 16),
                  if (info.sourceCharacter != null)
                    CharacterAvatar(
                      character: info.sourceCharacter!,
                      showIsSelected: false,
                      showName: true,
                      size: 160,
                    ),
                ],
                if (showsMadAbout) ...[
                  const SizedBox(height: 20),
                  _preparedLabel(localizedStrings.toBeMadAbout),
                ],
                if (showsPlayers) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final player in info.players)
                        info.kind == 'characterSelectedYouMadAboutPlayer'
                            ? CharacterAvatar(
                                character: player,
                                showIsSelected: false,
                                showName: true,
                                size: 150,
                              )
                            : _preparedPlayerToken(player),
                    ],
                  ),
                ],
                if (showsCharacter && info.selectedCharacter != null) ...[
                  const SizedBox(height: 20),
                  CharacterAvatar(
                    character: info.selectedCharacter!,
                    showIsSelected: false,
                    showName: true,
                    size: 180,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _preparedLabel(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFb5987d),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black, fontSize: 26),
        ),
      );

  Widget _preparedPlayerToken(Character player) => Container(
        width: 150,
        height: 150,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/token.png'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 54, color: Colors.black87),
            Text(
              player.playerName,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );

  Widget _buildDemonBluffs(
      BuildContext context, AppLocalizations localizedStrings) {
    final roleIds = context.select<GameStateService, List<String>>(
      (service) => service.demonBluffRoleIds,
    );
    final allCharacters = context.select<CharacterService, List<Character>>(
      (service) => service.allCharacters,
    );
    final bluffs = <Character>[];
    for (final roleId in roleIds) {
      for (final character in allCharacters) {
        if (character.roleId == roleId) {
          bluffs.add(character);
          break;
        }
      }
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(localizedStrings.demonBluffs,
            style: const TextStyle(color: Colors.white)),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                'assets/images/backgrounds/background_grim_middel.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: bluffs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(localizedStrings.noDemonBluffs,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18)),
                ),
              )
            : Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final character in bluffs)
                      CharacterAvatar(
                        character: character,
                        showIsSelected: false,
                        showName: true,
                        size: 150,
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStoredDemonBluffTokens(
      BuildContext context, AppLocalizations localizedStrings) {
    final roleIds = context.select<GameStateService, List<String>>(
      (service) => service.demonBluffRoleIds,
    );
    final allCharacters = context.select<CharacterService, List<Character>>(
      (service) => service.allCharacters,
    );
    final bluffs = <Character>[];
    for (final roleId in roleIds) {
      for (final character in allCharacters) {
        if (character.roleId == roleId) {
          bluffs.add(character);
          break;
        }
      }
    }
    if (bluffs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(localizedStrings.noDemonBluffs,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final character in bluffs)
          CharacterAvatar(
            character: character,
            showIsSelected: false,
            showName: true,
            size: 120,
          ),
      ],
    );
  }

  Container _buildCharacterSelection(
      BuildContext context,
      Character? character,
      Function(Character) onCharacterSelected,
      bool allCharacters,
      int position) {
    var maxHeight = MediaQuery.of(context).size.height;
    var maxWidth = MediaQuery.of(context).size.width;
    var localizedStrings = AppLocalizations.of(context)!;

    final characterService =
        Provider.of<CharacterService>(context, listen: false);

    final allOutSidersIngame = characterService.gameCharacters
        .where((element) => element.fraction == Fraction.outsider)
        .toList();

    var radius = 150.0;
    switch (selectedToken) {
      case Basictoken.these_chracters_are_not_in_play:
        radius = (maxHeight / 4) - 20;
        break;
      case Basictoken.this_chracter_selected_you:
        radius = maxWidth * 0.6;
        break;
      case Basictoken.these_are_all_outsiders:
        radius = (maxWidth / allOutSidersIngame.length) - 20;
        if (position > allOutSidersIngame.length) {
          return Container();
        }
        onCharacterSelected(allOutSidersIngame[position - 1]);
        character = allOutSidersIngame[position - 1];
        break;
      default:
        radius = maxWidth * 0.8;
        break;
    }
    return Container(
      width: radius, // Breite des Kreises
      height: radius,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          _showChangeCharacterDialog(
              context, onCharacterSelected, allCharacters);
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
            : Container(
                width: radius,
                height: radius,
                child: Center(
                    child: Text(localizedStrings.clickHere,
                        style: TextStyle(
                            fontSize: radius * 0.15, color: Colors.black))),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage(
                        'assets/images/backgrounds/token.png'), // Zweites Bild
                    fit: BoxFit.cover,
                  ),
                ),
              ),
      ),
    );
  }

  List<DropdownMenuItem<Basictoken>> _getDropdownItems(
      BuildContext context, bool inMenu) {
    return [
      _dropdownMenuItem(context, Basictoken.empty_string, inMenu),
      _dropdownMenuItem(context, Basictoken.this_is_the_demon, inMenu),
      _dropdownMenuItem(context, Basictoken.these_are_your_minions, inMenu),
      _dropdownMenuItem(
          context, Basictoken.these_chracters_are_not_in_play, inMenu),
      _dropdownMenuItem(context, Basictoken.you_are, inMenu),
      _dropdownMenuItem(context, Basictoken.this_player_is, inMenu),
      _dropdownMenuItem(context, Basictoken.this_chracter_selected_you, inMenu),
      _dropdownMenuItem(context, Basictoken.did_you_vote_today, inMenu),
      _dropdownMenuItem(context, Basictoken.did_you_nominate_today, inMenu),
      _dropdownMenuItem(context, Basictoken.these_are_all_outsiders, inMenu),
      _dropdownMenuItem(context, Basictoken.choose_a_character, inMenu),
    ];
  }

  DropdownMenuItem<Basictoken> _dropdownMenuItem(
      BuildContext context, Basictoken token, bool inMenu) {
    var maxWidth = MediaQuery.of(context).size.width;
    return DropdownMenuItem(
      value: token,
      child: Container(
        width: maxWidth - 100,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFb5987d),
        ),
        child: Center(
            child: Text(
          getTokenText(token),
          textAlign: TextAlign.center,
          style: TextStyle(
              color: inMenu ? Colors.black : Colors.black,
              fontSize: inMenu ? 14 : 28),
          overflow: TextOverflow
              .ellipsis, // Schneidet den Text ab, wenn nicht genug Platz ist
          softWrap: false, // Verhindert Zeilenumbruch, nützlich in Dropdowns
        )),
      ),
    );
  }

  String getTokenText(Basictoken selectedToken) {
    var localizedStrings = AppLocalizations.of(context)!;
    switch (selectedToken) {
      case Basictoken.this_chracter_selected_you:
        return localizedStrings.this_chracter_selected_you;
      case Basictoken.you_are:
        return localizedStrings.you_are;
      case Basictoken.this_player_is:
        return localizedStrings.this_player_is;
      case Basictoken.this_is_the_demon:
        return localizedStrings.this_is_the_demon;
      case Basictoken.these_are_your_minions:
        return localizedStrings.these_are_your_minions;
      case Basictoken.these_chracters_are_not_in_play:
        return localizedStrings.these_chracters_are_not_in_play;
      case Basictoken.these_are_all_outsiders:
        return localizedStrings.these_are_all_outsiders;
      case Basictoken.did_you_vote_today:
        return localizedStrings.did_you_vote_today;
      case Basictoken.did_you_nominate_today:
        return localizedStrings.did_you_nominate_today;
      case Basictoken.choose_a_character:
        return localizedStrings.choose_a_character;
      case Basictoken.empty_string:
        return localizedStrings.empty_string;
    }
  }

  void _showChangeCharacterDialog(BuildContext context,
      Function(Character) onCharacterSelected, bool allChraracters) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameCharacters =
        characterService.gameCharactersBackupWithoutDrunkAndFabled;
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final allCharactersOfGameset = scriptService
        .resolveCharacters(characterService.allCharacters)
        .where((element) => element.fraction != Fraction.fabled)
        .toList();

    var charactersToChooseFrom =
        allChraracters ? allCharactersOfGameset : gameCharacters;

    if (selectedToken == Basictoken.these_chracters_are_not_in_play) {
      var chraractersNotInGame = allCharactersOfGameset
          .where((element) =>
              !gameCharacters.contains(element) &&
              (element.fraction == Fraction.townsfolk ||
                  element.fraction == Fraction.outsider))
          .toList();
      charactersToChooseFrom = chraractersNotInGame;
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SelectOneCharater(
                charactersToChooseFrom: charactersToChooseFrom,
                onConfirm: (Character selectedCharacter) {
                  onCharacterSelected(selectedCharacter);
                },
                title: getTokenText(selectedToken),
                needToConfirm: false,
                confirmButtonText: "Ok")));
  }
}
