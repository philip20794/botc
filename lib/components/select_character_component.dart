import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/components/show_character.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/services/role_multiplicity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectCharacterComponent extends StatefulWidget {
  final List<Character> charactersToChooseFrom;
  final bool travellersAreSelectable;
  final bool fabledAreSelectable;
  final int numberOfCharactersToSelect;
  final bool isForSetupGame;
  final bool forSetupIsDone;
  final bool needToConfirm;
  final String title;
  final String confirmButtonText;
  final Function() onConfirm;
  final Function(List<Character> characters)? onResult;
  final IconData confirmButtonIcon;
  final List<String> validationMessages;
  final bool blockConfirmWhenDisabled;
  final bool demonBluffsEnabled;
  final bool showBackground;

  SelectCharacterComponent({
    required this.charactersToChooseFrom,
    required this.onConfirm,
    required this.title,
    required this.confirmButtonText,
    this.onResult,
    this.travellersAreSelectable = false,
    this.fabledAreSelectable = false,
    this.numberOfCharactersToSelect = 1,
    this.isForSetupGame = false,
    this.forSetupIsDone = false,
    this.confirmButtonIcon = Icons.remove_red_eye,
    this.needToConfirm = true,
    this.validationMessages = const [],
    this.blockConfirmWhenDisabled = false,
    this.demonBluffsEnabled = true,
    this.showBackground = true,
  });

  _SelectCharacterComponentState createState() =>
      _SelectCharacterComponentState();
}

class _SelectCharacterComponentState extends State<SelectCharacterComponent> {
  List<Character> result = [];

  void selectCharacter(Character character) {
    if (result.contains(character)) {
      result.remove(character);
    } else {
      if (result.length >= widget.numberOfCharactersToSelect) {
        result.removeAt(0);
      }
      result.add(character);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final gameStateService =
          Provider.of<GameStateService>(context, listen: false);
      gameStateService.closeMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    CharacterService characterService = Provider.of<CharacterService>(context);
    // Rebuild token borders when a persistent bluff selection changes.
    Provider.of<GameStateService>(context);

    List<Character> townsfolk = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.townsfolk)
        .toList();
    List<Character> outsider = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.outsider)
        .toList();
    List<Character> minion = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.minion)
        .toList();
    List<Character> demon = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.demon)
        .toList();
    List<Character> travellers = widget.charactersToChooseFrom
        .where((element) => element.fraction == Fraction.traveller)
        .toList();
    List<Character> fabled = characterService.allCharacters
        .where((element) => element.fraction == Fraction.fabled)
        .toList();

    final content = Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(
              top: 8, left: 8, right: 8, bottom: widget.needToConfirm ? 64 : 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCharacterSection(context, 'Townsfolk', townsfolk, false),
                Divider(color: GrimoireColors.antiqueGold.withValues(alpha: 0.22)),
                _buildCharacterSection(context, 'Outsider', outsider, false),
                Divider(color: GrimoireColors.antiqueGold.withValues(alpha: 0.22)),
                _buildCharacterSection(context, 'Minion', minion, false),
                Divider(color: GrimoireColors.antiqueGold.withValues(alpha: 0.22)),
                _buildCharacterSection(context, 'Demon', demon, false),
                if (widget.travellersAreSelectable) ...[
                  Divider(color: GrimoireColors.antiqueGold.withValues(alpha: 0.38)),
                  _buildCharacterSection(
                      context, 'Traveller', travellers, true),
                ],
                if (widget.fabledAreSelectable) ...[
                  Divider(color: GrimoireColors.antiqueGold.withValues(alpha: 0.22)),
                  _buildCharacterSection(context, 'Fabled', fabled, true),
                ],
              ],
            ),
          ),
        ),
        if (widget.needToConfirm) ...[
          NextScreenFooter(
            nextScreenName: widget.confirmButtonText,
            nextScreenIcon: widget.confirmButtonIcon,
            currentScreenName: widget.title,
            hideHomeButton: !widget.isForSetupGame,
            disabled: !isDone(),
            validationMessages: widget.validationMessages,
            blockNavigationWhenDisabled: widget.blockConfirmWhenDisabled,
            onTap: () {
              widget.onConfirm();
              if (widget.onResult != null) {
                widget.onResult!(result);
              }
            },
          )
        ],
      ],
    );

    return widget.showBackground ? AppBackground(child: content) : content;
  }

  Widget _buildCharacterSection(BuildContext context, String title,
      List<Character> characters, bool showHideButton) {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final settingsService = Provider.of<SettingsService>(context);
    final characterService = Provider.of<CharacterService>(context);
    bool hidden = false;
    var maxWidth = MediaQuery.of(context).size.width;

    if (title == 'Traveller') {
      hidden = settingsService.hideTravellers;
    } else if (title == 'Fabled') {
      hidden = settingsService.hideFabled;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: GestureDetector(
                onTap: () {
                  if (!showHideButton) {
                    return;
                  }
                  setState(() {
                    if (title == 'Traveller') {
                      settingsService.hideTravellers =
                          !settingsService.hideTravellers;
                    } else if (title == 'Fabled') {
                      settingsService.hideFabled = !settingsService.hideFabled;
                    }
                  });
                },
                child: Row(children: [
                  if (showHideButton) ...[
                    Icon(
                      hidden ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                      color: GrimoireColors.antiqueGold,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        color: GrimoireColors.antiqueGold,
                        fontWeight: FontWeight.bold),
                  ),
                  if (!hidden) ...[
                    const SizedBox(width: 20),
                    ToggleButtons(
                      constraints:
                          const BoxConstraints(minHeight: 30, minWidth: 60),
                      borderRadius: BorderRadius.circular(10),
                      borderColor: GrimoireColors.antiqueGold.withValues(alpha: 0.42),
                      selectedColor: GrimoireColors.background,
                      fillColor: GrimoireColors.antiqueGold,
                      isSelected: [
                        characterService.showInfoButtonOnCharacterSelection,
                        !characterService.showInfoButtonOnCharacterSelection
                      ],
                      onPressed: (int index) {
                        gameStateService.closeMenu();
                        setState(() {
                          characterService.showInfoButtonOnCharacterSelection =
                              index == 0;
                        });
                      },
                      children: const [
                        Icon(Icons.help, color: GrimoireColors.ivory),
                        Icon(Icons.circle_outlined, color: GrimoireColors.ivory),
                      ],
                    ),
                  ],
                ]))),
        if (!hidden) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // Anzahl der Spalten im Grid
              crossAxisSpacing: 0, // Abstand zwischen den Spalten
              mainAxisSpacing: 0, // Abstand zwischen den Zeilen
            ),
            itemCount:
                characters.length, // Anzahl der Charaktere in der Fraktion
            itemBuilder: (context, index) {
              Character character = characters[index];

              // Prüfen, ob der Charakter bereits ausgewählt ist
              bool isSelected = widget.isForSetupGame
                  ? characterService.containsCharacter(
                      characterService.gameCharacters, character)
                  : result.contains(character);
              final isBluff = widget.isForSetupGame &&
                  gameStateService.isDemonBluff(character.roleId);
              final isEligibleBluff = widget.demonBluffsEnabled &&
                  (character.fraction == Fraction.townsfolk ||
                      character.fraction == Fraction.outsider);

              return GestureDetector(
                  onLongPress: () {
                    if (characterService.showInfoButtonOnCharacterSelection) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) =>
                            ShowCharacter(character: character)));
                    } else if (widget.isForSetupGame &&
                        !RoleMultiplicity.storytellerChooses(character.roleId)) {
                      gameStateService.toggleDemonBluff(
                        character.roleId,
                        isEligible: isEligibleBluff || isBluff,
                        isGameCharacter: isSelected,
                      );
                    }
                  },
                  onTap: () async {
                    if (characterService.showInfoButtonOnCharacterSelection) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) =>
                            ShowCharacter(character: character)));
                    } else if (widget.isForSetupGame) {
                      if (isBluff) return;
                      if (isSelected) {
                        characterService.removeCharacter(character);
                      } else if (RoleMultiplicity.storytellerChooses(
                          character.roleId)) {
                        final count = await showCharacterExemplarDialog(
                          context,
                          character,
                          gameStateService.playerNames.length,
                        );
                        if (count == null || !mounted) return;
                        characterService.addCharacter(character,
                            exemplars: count,
                            playerCount: gameStateService.playerNames.length);
                      } else {
                        characterService.addCharacter(character);
                      }
                    } else {
                      setState(() {
                        selectCharacter(character);
                        if (!widget.needToConfirm) {
                          widget.onConfirm();
                          widget.onResult?.call(result);
                        }
                      });
                    }
                  },
                  child: CharacterAvatar(
                      character: character,
                      showIsSelected: true,
                      forSelectCharacter: true,
                      isSelected: isSelected,
                      isBluff: isBluff,
                      showExemplare: widget.isForSetupGame &&
                          RoleMultiplicity.trackedRoles.contains(character.roleId),
                      exemplarLabel: widget.isForSetupGame
                          ? _multiplicityBadge(character, characterService,
                              gameStateService.playerNames.length)
                          : null,
                      size: maxWidth / 4,
                      showName: true));
            },
          ),
        ],
      ],
    );
  }

  bool isDone() {
    return widget.isForSetupGame
        ? widget.forSetupIsDone
        : result.length == widget.numberOfCharactersToSelect;
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

  String _multiplicityBadge(Character character,
      CharacterService characters, int playerCount) {
    final selected = characters.gameCharacters
        .where((role) => role.roleId == character.roleId)
        .length;
    if (selected > 0) return '$selected';
    // Riot's final count is unknown until Minions transform on day 3;
    // Farmer can generate more instances through nightly deaths.
    if (character.roleId == 'riot' || character.roleId == 'farmer') {
      return 'n';
    }
    return RoleMultiplicity.storytellerChooses(character.roleId)
        ? 'n'
        : '1';
  }

  Future<int?> showCharacterExemplarDialog(
      BuildContext context, Character character, int playerCount) {
    final allowed =
        RoleMultiplicity.allowedCounts(character.roleId, playerCount);
    if (allowed.isEmpty) {
      return showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keine gültige Anzahl'),
          content: Text(
              'Für $playerCount Spieler ist hier keine gültige Anzahl möglich.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Schließen')),
          ],
        ),
      );
    }
    var selected = allowed.first;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e),
          title: Text('${character.name} – Anzahl',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$selected',
                  key: const ValueKey('exemplar-count-value'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              Slider(
                key: const ValueKey('exemplar-count-slider'),
                min: 0,
                max: (allowed.length - 1).toDouble(),
                divisions: allowed.length > 1 ? allowed.length - 1 : null,
                value: allowed.indexOf(selected).toDouble(),
                label: '$selected',
                onChanged: allowed.length == 1
                    ? null
                    : (value) => update(() {
                          selected = allowed[value.round()];
                        }),
              ),
              Text('${allowed.first}–${allowed.last}',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              key: const ValueKey('confirm-exemplar-count'),
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}
