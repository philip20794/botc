import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class ShowCharacter extends StatefulWidget {
  final Character character;
  final bool showDescriptionShort;
  final bool showDescriptionLong;
  final bool showMoreDetails;
  final bool showHowToRun;
  final bool imageLarge;

  ShowCharacter({
    required this.character,
    this.showDescriptionShort = true,
    this.showDescriptionLong = true,
    this.imageLarge = false,
    this.showHowToRun = true,
    this.showMoreDetails = false,
  });

  @override
  _ShowCharacterState createState() => _ShowCharacterState();
}

class _ShowCharacterState extends State<ShowCharacter> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.character.name,
            style: const TextStyle(color: Colors.white)),
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
                  // Character Name
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.character.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Character Image
                  if (widget.imageLarge) ...[
                    CharacterAvatar(
                        character: widget.character,
                        showIsSelected: false,
                        showName: true,
                        size: MediaQuery.of(context).size.width / 2),
                  ] else ...[
                    CharacterAvatar(
                        character: widget.character,
                        showIsSelected: false,
                        size: 200,
                        showName: true)
                  ],

                  // Short Description
                  if (widget.showDescriptionShort) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 32.0),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Überschrift linksbündig
                        children: [
                          const SizedBox(
                              height:
                                  8.0), // Platz zwischen Überschrift und Text
                          Text(
                            widget.character.descriptionShort,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Long Description
                  if (widget.showDescriptionLong) ...[
                    _buildExpandableText(0),
                  ],

                  // How to Run
                  if (widget.showHowToRun) ...[
                    _buildExpandableText(1),
                  ],

                  if (widget.showMoreDetails) ...[
                    _buildExpandableText(2),
                    _buildExpandableText(3),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getTitle(int index) {
    var localizedStrings = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return localizedStrings.description;
      case 1:
        return localizedStrings.howToRun;
      case 2:
        return localizedStrings.tipsAndTricks;
      case 3:
        return widget.character.fraction == Fraction.demon ||
                widget.character.fraction == Fraction.minion
            ? localizedStrings.fightingAgainst(widget.character.name)
            : localizedStrings.bluffs(widget.character.name);
      default:
        return '';
    }
  }

  List<String> getText(int index) {
    switch (index) {
      case 0:
        return widget.character.descriptionLong
            .split("\n")
            .where((list) => list.isNotEmpty)
            .toList();
      case 1:
        return widget.character.howToRun.split("\n");
      case 2:
        return widget.character.tipsAndTricks;
      case 3:
        return widget.character.bluffs;
      default:
        return [];
    }
  }

  bool getIsOpen(int index) {
    final settingsService = Provider.of<SettingsService>(context);
    switch (index) {
      case 0:
        return !settingsService.hideDescription;
      case 1:
        return !settingsService.hideHotToRun;
      case 2:
        return !settingsService.hideTipsAndTricks;
      case 3:
        return !settingsService.hideBluffs;
      default:
        return false;
    }
  }

  void toggleOpen(int index) {
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);
    switch (index) {
      case 0:
        settingsService.hideDescription = !settingsService.hideDescription;
        break;
      case 1:
        settingsService.hideHotToRun = !settingsService.hideHotToRun;
        break;
      case 2:
        settingsService.hideTipsAndTricks = !settingsService.hideTipsAndTricks;
        break;
      case 3:
        settingsService.hideBluffs = !settingsService.hideBluffs;
        break;
    }
  }

  Widget _buildExpandableText(int index) {
    var open = getIsOpen(index);
    var titel = getTitle(index);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
              onTap: () {
                setState(() {
                  toggleOpen(index);
                });
              },
              child: Row(
                children: [
                  Icon(open ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      color: Colors.white),
                  Text(
                    titel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )),
          const SizedBox(height: 8.0),
          if (open) ...[
            Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: getText(index).asMap().entries.map((entry) {
                        int idx = entry.key; // Der Index des Elements
                        String point = entry.value; // Der Text des Elements

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nur Bullet Point für alle Elemente außer dem ersten
                            if ((idx != 0 && index != 0) && index != 1)
                              const Text("➥ ",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black)),
                            // Text für das Element
                            Expanded(
                              child: Text(
                                point,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ))),
          ],
        ],
      ),
    );
  }
}
