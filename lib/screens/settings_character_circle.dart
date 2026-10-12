import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/quick_flow_bar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

class SettingsCharacterCircle extends StatefulWidget {
  @override
  _SettingsCharacterCircleState createState() =>
      _SettingsCharacterCircleState();
}

class _SettingsCharacterCircleState extends State<SettingsCharacterCircle> {
  var numberOfCharacters = 12.0;
  List<Character> randomCharacters = [];

  @override
  void initState() {
    super.initState();
    generateRandomCharacter(context);
  }

  void generateRandomCharacter(BuildContext context) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    randomCharacters =
        characterService.getRandomCharacter(numberOfCharacters.toInt());
  }

  void updateNumberOfCharacters(double newValue) {
    numberOfCharacters = newValue;
    generateRandomCharacter(context);
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final characterService = Provider.of<CharacterService>(context);
    final gameStateService = Provider.of<GameStateService>(context);
    var localizedStrings = AppLocalizations.of(context)!;
    final previewTokens = _previewTokens(characterService);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            if (gameStateService
                .quickFlowEntries(characterService.gameCharacters)
                .isNotEmpty)
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -78),
                  child: QuickFlowBar(
                    gameCharacters: characterService.gameCharacters,
                    allCharacters: characterService.allCharacters,
                    gameState: gameStateService,
                    readOnly: true,
                  ),
                ),
              ),
            // Character Circle Component
            if (randomCharacters.isNotEmpty) ...[
              Positioned.fill(
                child: CharacterCircleComponent(
                  key: const ValueKey('layout-settings-character-circle'),
                  settingsView: true,
                  characters: randomCharacters,
                  charactersForToken: randomCharacters,
                  previewTokensByCharacterId: previewTokens,
                ),
              ),
            ],
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Text(
                      localizedStrings.layoutSettings,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 56, bottom: 16),
                  child: SizedBox(
                    width: 300,
                    height: 750,
                    child: _buildSettingsDialog(context, settingsService),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Token>> _previewTokens(CharacterService characterService) {
    const preferredNames = {'mad', 'poisoned', 'drunk'};
    final tokenCharacters = characterService.allCharacters.isEmpty
        ? randomCharacters
        : characterService.allCharacters;
    final allTokens = tokenCharacters
        .expand((character) => character.tokens)
        .toList(growable: false);
    final configuredExamples = [
      ...allTokens.where(
        (token) => preferredNames.contains(token.name.toLowerCase()),
      ),
      ...allTokens.where(
        (token) => !preferredNames.contains(token.name.toLowerCase()),
      ),
    ].take(3).toList(growable: false);
    final examples = configuredExamples.isNotEmpty
        ? configuredExamples
        : [
            Token(name: 'Mad', image: 'Icon_cerenovus'),
            Token(name: 'Poisoned', image: 'Icon_poisoner'),
            Token(name: 'Drunk', image: 'Icon_drunk'),
          ];
    return {
      for (var index = 0; index < randomCharacters.length; index++)
        randomCharacters[index].id: [
          for (var tokenIndex = 0; tokenIndex <= index % 3; tokenIndex++)
            examples[(index + tokenIndex) % examples.length],
        ],
    };
  }

  // Funktion zum Erstellen des "Dialogs" mit Slidern
  Widget _buildSettingsDialog(
      BuildContext context, SettingsService settingsService) {
    var localizedStrings = AppLocalizations.of(context)!;
    return Card(
      elevation: 5,
      color: Color(0xFF4a3b5e).withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedStrings.characterSettings,
                style: TextStyle(fontSize: 20),
              ),
              _buildSliderWithHelp(
                title: localizedStrings.characterSize,
                value: settingsService.characterKnobSize,
                min: 60,
                max: 140,
                onChanged: (newValue) {
                  settingsService.setCharacterKnobSize(newValue,
                      persist: false);
                },
                helpText: 'Adjust the size of the character knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.numberPerRow,
                value: settingsService.startAngleDiv.toDouble(),
                min: 2,
                max: 5,
                onChanged: (newValue) {
                  settingsService.setStartAngleDiv(newValue, persist: false);
                },
                helpText: 'Adjust the starting angle of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.distanceX,
                value: settingsService.radiusX,
                min: 5,
                max: 109,
                onChanged: (newValue) {
                  settingsService.setRadiusX(newValue, persist: false);
                },
                helpText: 'Adjust the horizontal radius of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.distanceY,
                value: settingsService.radiusY,
                min: 30,
                max: 235,
                onChanged: (newValue) {
                  settingsService.setRadiusY(newValue, persist: false);
                },
                helpText: 'Adjust the vertical radius of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.numberOfCharacters,
                value: numberOfCharacters,
                min: 6,
                max: 18,
                onChanged: (newValue) {
                  setState(() {
                    updateNumberOfCharacters(newValue);
                  });
                },
                helpText: 'Adjust the size of the character knob.',
              ),
              Text(
                localizedStrings.tokenSettings,
                style: TextStyle(fontSize: 20),
              ),
              _buildSliderWithHelp(
                title: localizedStrings.tokenSize,
                value: settingsService.tokenKnobSize,
                min: 10,
                max: 60,
                onChanged: (newValue) {
                  settingsService.setTokenKnobSize(newValue, persist: false);
                },
                helpText: 'Adjust the size of the token knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.tokenOffsetX,
                value: settingsService.tokenOffsetX,
                min: -35,
                max: 70,
                onChanged: (newValue) {
                  settingsService.setTokenOffsetX(newValue, persist: false);
                },
                helpText: 'Adjust the size of the token knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.tokenOffsetY,
                value: settingsService.tokenOffsetY,
                min: -40,
                max: 80,
                onChanged: (newValue) {
                  settingsService.setTokenOffsetY(newValue, persist: false);
                },
                helpText: 'Adjust the size of the token knob.',
              ),
              Text(
                localizedStrings.reminderTokenSettings,
                style: const TextStyle(fontSize: 20),
              ),
              _buildSliderWithHelp(
                title: localizedStrings.selectedReminderSize,
                value: settingsService.selectedReminderTokenSize,
                min: 24,
                max: 80,
                onChanged: (newValue) => settingsService
                    .setSelectedReminderTokenSize(newValue, persist: false),
                helpText: 'Adjust the selected reminder token size.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.unselectedReminderSize,
                value: settingsService.unselectedReminderTokenSize,
                min: 12,
                max: 48,
                onChanged: (newValue) => settingsService
                    .setUnselectedReminderTokenSize(newValue, persist: false),
                helpText: 'Adjust the unselected reminder token size.',
              ),
              Text(
                localizedStrings.containerSettings,
                style: TextStyle(fontSize: 20),
              ),
              _buildSliderWithHelp(
                title: localizedStrings.containerOffsetX,
                value: settingsService.offsetX,
                min: -145,
                max: 55,
                onChanged: (newValue) {
                  settingsService.setOffsetX(newValue, persist: false);
                },
                helpText: 'Adjust the X-axis offset of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.containerOffsetY,
                value: settingsService.offsetY,
                min: -185,
                max: 25,
                onChanged: (newValue) {
                  settingsService.setOffsetY(newValue, persist: false);
                },
                helpText: 'Adjust the Y-axis offset of the circle.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hilfsfunktion zum Erstellen eines Sliders mit einem Help-Icon
  Widget _buildSliderWithHelp({
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String helpText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(title),
          ),
          Expanded(
            flex: 5,
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (newValue) {
                onChanged(newValue);
              },
              onChangeEnd: (_) {
                Provider.of<SettingsService>(context, listen: false)
                    .saveSettings();
              },
            ),
          ),
        ],
      ),
    );
  }
}
