import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/select_one_charater.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class CharacterWidget extends StatefulWidget {
  final Character character;
  final bool showInfo;
  final bool showLongDescription;
  final bool showSelect;
  final bool showHowToRun;
  final bool showIsSelected;
  final bool showAddToken; // Neuer Prop für den Menüpunkt
  final bool showToggleAlive;
  final bool showCharacter;
  final bool imageLarge;
  final bool showChangeCharacter;
  final bool showDeadOverlay;
  final int menuId;
  final bool settingsView;
  final bool characterSelectionView;
  final Function(Character) onSelect;

  CharacterWidget({
    required this.character,
    this.showInfo = true,
    this.showLongDescription = true,
    this.showSelect = true,
    this.showHowToRun = true,
    this.showIsSelected = true,
    this.showAddToken = false,
    this.showToggleAlive = false,
    this.showCharacter = false,
    this.imageLarge = false,
    this.showChangeCharacter = false,
    this.showDeadOverlay = false,
    this.settingsView = false,
    this.characterSelectionView = false,
    required this.menuId,
    required this.onSelect,
  });

  @override
  _CharacterWidgetState createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  bool isSelected = false;
  bool showMenu = false;
  bool showCharacterDialog = false;

  void toggleSelection(BuildContext context) {
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    setState(() {
      isSelected = !isSelected;
    });
    gameStateService.reset(characterService.gameCharacters);
    widget.onSelect(widget.character); // Callback-Funktion aufrufen
    showMenu = gameStateService.openMenuId == widget.menuId;
  }

  void toggleAlive(BuildContext context) {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    gameStateService.toggleCharacterAlive(widget.character);
    showMenu = false; // Menü verstecken
  }

  void toggleMenu(BuildContext context) {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    showMenu = gameStateService.openMenuId == widget.menuId;
    setState(() {
      if (showMenu) {
        gameStateService.closeMenu();
      } else {
        gameStateService.openMenu(widget.menuId);
      }
    });
  }

  void setPlayerName(BuildContext context) {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    var index = characterService.getCharacterIndex(widget.character);
    if (index > -1 && gameStateService.playerNames.length > index) {
      var playerName = gameStateService.playerNames[index];
      characterService.setNameOfCharacter(widget.character, playerName);
    }
  }

  void toggleShowCharacter() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ShowCharacter(
                  character: widget.character,
                  showDescriptionShort: widget.showInfo,
                  showDescriptionLong: widget.showLongDescription,
                  showHowToRun: widget.showHowToRun,
                  imageLarge: widget.imageLarge,
                )));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setPlayerName(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    CharacterService characterService = Provider.of<CharacterService>(context);
    SettingsService settingsService = Provider.of<SettingsService>(context);
    isSelected = gameStateService.nightCount > 0
        ? gameStateService.isCharacterAwake(widget.character)
        : characterService.containsCharacter(
            characterService.gameCharacters, widget.character);

    // Überprüfen, ob der Charakter lebendig ist
    final bool isAlive = gameStateService.isCharacterAlive(widget.character);

    final maxWidth = MediaQuery.of(context).size.width;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (widget.characterSelectionView &&
                !characterService.showInfoButtonOnCharacterSelection) {
              toggleSelection(context);
              return;
            } else if (widget.characterSelectionView &&
                characterService.showInfoButtonOnCharacterSelection) {
              toggleShowCharacter();
              return;
            }
            toggleMenu(context);
          },
          child: CharacterAvatar(
            character: widget.character,
            showIsSelected: widget.showIsSelected,
            showName: true,
            size: settingsService.characterKnobSize,
          ),
        ),

        // Bild, wenn der Charakter nicht lebendig ist
        if (!isAlive &&
            widget.showDeadOverlay &&
            !widget.settingsView &&
            !widget.characterSelectionView) ...[
          Positioned(
            top: 18,
            child: GestureDetector(
              onTap: () {
                toggleMenu(context);
              },
              child: Image.asset(
                'assets/images/dead_character_overlay.png', // Dein Bild für nicht lebendig
                // width: settingsService.characterKnobSize * 0.5,
                height: settingsService.characterKnobSize * 0.7,
                fit: BoxFit.cover,
              ),
            ),
          )
        ],

        // Tokens im Kreis um das Charakterbild
        if (gameStateService.tokensOfCharacter(widget.character).isNotEmpty &&
            widget.showAddToken) ...[
          ..._buildTokenWidgets(context),
        ],

        // Charaktername über dem Bild
        if (widget.character.playerName.isNotEmpty &&
            !widget.settingsView &&
            !widget.characterSelectionView) ...[
          Positioned(
            top:
                10, // Position anpassen, um den Namen über dem Bild zu platzieren
            child: Container(
              width: settingsService.characterKnobSize * 0.8,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF493131)),
              child: Center(
                child: SizedBox(
                  width: settingsService.characterKnobSize * 0.8,
                  child: AutoSizeText(
                    widget.character.playerName,
                    textAlign: TextAlign.center,
                    minFontSize: 4,
                    maxFontSize: 12,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          )
        ],

        // Halbkreis-Menü
        if (gameStateService.openMenuId == widget.menuId &&
            !widget.settingsView) ...[
          Positioned(
            top: 0,
            right: 20,
            child: _buildMenuIcon(Icons.add, widget.showAddToken, () {
              _showAddTokenDialog(context, widget.character);
              gameStateService.closeMenu();
            }),
          ),
          Positioned(
            top: 0,
            right: 20,
            child: _buildMenuIcon(isSelected ? Icons.cancel : Icons.check,
                widget.characterSelectionView, () {
              toggleSelection(context);
              gameStateService.closeMenu();
            }),
          ),
          Positioned(
            top: settingsService.characterKnobSize * 0.35,
            right: 0,
            child: _buildMenuIcon(Icons.info,
                widget.showCharacter || widget.showInfo || widget.showHowToRun,
                () {
              toggleShowCharacter();
              gameStateService.closeMenu();
            }),
          ),
          Positioned(
            bottom: settingsService.characterKnobSize * 0.35,
            right: 0,
            child: _buildMenuIcon(
                CustomIcons.change, widget.showChangeCharacter, () {
              _showChangeCharacterDialoge(context, widget.character);
              gameStateService.closeMenu();
            }),
          ),
          Positioned(
            bottom: 0,
            right: 20,
            child: _buildMenuIcon(
                isAlive ? CustomIcons.grave : CustomIcons.life,
                widget.showToggleAlive, () {
              toggleAlive(context);
              gameStateService.closeMenu();
            }),
          ),
          Positioned(
            right: 55,
            bottom: -10,
            child: _buildMenuIcon(
                Icons.flip_camera_android, widget.showAddToken, () {
              setState(() {
                characterService.flipCharacter(widget.character);
              });
              gameStateService.closeMenu();
            }),
          ),
        ],
      ],
    );
  }

  // Methode zum Erstellen der Token-Widgets im Kreis
  List<Widget> _buildTokenWidgets(BuildContext context) {
    final gameStateService = Provider.of<GameStateService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    const double radius = 80.0; // Radius des Kreises um das Charakterbild
    final tokens = gameStateService.tokensOfCharacter(widget.character);
    final int tokenCount = tokens.length;
    final List<Widget> tokenWidgets = [];

    for (int i = 1; i <= tokenCount; i++) {
      final double angle = 0.5 * pi * i / tokenCount;
      final double xOffset = radius * cos(angle);
      final double yOffset = radius * sin(angle);

      var tokenID = widget.character.id + tokens[i - 1].name;

      tokenWidgets.add(Positioned(
        left: settingsService.tokenOffsetX +
            xOffset -
            20, // 20 ist die halbe Breite der Tokens
        top: settingsService.tokenOffsetY +
            yOffset -
            20, // 20 ist die halbe Höhe der Tokens
        child: GestureDetector(
          onTap: () {
            setState(() {
              if (gameStateService.openTokenMenuId == tokenID) {
                gameStateService.removeTokenFromCharacter(
                    widget.character, tokens[i - 1]);
                gameStateService.closeMenu();
                return;
              } else {
                gameStateService.openTokenMenu(tokenID);
              }
            });
          },
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF493131),
            ),
            child: Padding(
                padding: EdgeInsets.all(settingsService.tokenKnobSize * 0.11),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: settingsService.tokenKnobSize,
                      height: settingsService.tokenKnobSize * 0.6,
                      alignment: Alignment.center,
                      child: gameStateService.openTokenMenuId == tokenID
                          ? Icon(Icons.close, color: Colors.white)
                          : CircleAvatar(
                              radius: settingsService.tokenKnobSize,
                              backgroundImage: AssetImage(
                                  roleImageAssetPath(tokens[i - 1].image)),
                              backgroundColor: const Color(0xFF493131),
                            ),
                    ),
                    SizedBox(
                      width: settingsService.tokenKnobSize * 0.8,
                      child: AutoSizeText(
                        tokens[i - 1].name,
                        textAlign: TextAlign.center,
                        minFontSize: 4,
                        maxFontSize: 12,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Ein kleiner Abstand zwischen Bild und Text

                    const SizedBox(height: 2),
                  ],
                )),
          ),
        ),
      ));
    }

    return tokenWidgets;
  }

  // Menü-Icon erstellen
  Widget _buildMenuIcon(IconData icon, bool isVisible, VoidCallback onPressed) {
    final settingsService = Provider.of<SettingsService>(context);
    if (!isVisible)
      return const SizedBox
          .shrink(); // Wenn die Option nicht angezeigt werden soll, wird nichts angezeigt
    return GestureDetector(
      onTap: onPressed,
      child: CircleAvatar(
        radius: settingsService.characterKnobSize * 0.2,
        backgroundColor: const Color(0xFF4a3b5e),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
    );
  }

  // Neuen Dialog hinzufügen, um alle Tokens anzuzeigen und einen auszuwählen
  void _showAddTokenDialog(BuildContext context, Character character) {
    var localizedStrings = AppLocalizations.of(context)!;
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    final allTokens = gameStateService.getAllTokensInGame(
        characterService.gameCharacters, characterService.gameCharactersBackup);
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
          title: Text(
              '${localizedStrings.chooseTokenFor} ${character.playerName} (${character.name})',
              style: const TextStyle(color: Colors.white)),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: allTokens.length,
              itemBuilder: (context, index) {
                final token = allTokens[index];
                return ListTile(
                  tileColor: gameStateService.isTokenUsed(token)
                      ? Colors.transparent
                      : const Color(0xFF6f678a),
                  minVerticalPadding: 20,
                  leading: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.transparent,
                    backgroundImage:
                        AssetImage(roleImageAssetPath(token.image)),
                  ),
                  title: Text(token.name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    gameStateService.addTokenToCharacter(
                        characterService.allCharacters, character, token);
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

  void _showChangeCharacterDialoge(
      BuildContext context, Character oldCharacter) {
    var localizedStrings = AppLocalizations.of(context)!;
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final allCharactersOfGameset =
        scriptService.resolveCharacters(characterService.allCharacters);

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SelectOneCharater(
                charactersToChooseFrom: allCharactersOfGameset,
                onConfirm: (newCharacter) {
                  var idOfNewCharacter = characterService.changeCharacter(
                      oldCharacter, newCharacter);
                  gameStateService.giveAllTokensFromCharacterAToCharacterB(
                      characterService.allCharacters,
                      oldCharacter,
                      idOfNewCharacter);
                  // Navigator.pop(context);
                },
                title:
                    '${localizedStrings.chooseNewCharacterFor} ${oldCharacter.playerName} (${oldCharacter.name})',
                confirmButtonText:
                    "${localizedStrings.assign} ${oldCharacter.playerName}")));
  }
}
