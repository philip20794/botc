import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
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

class _SettingsCharacterCircleState extends State<SettingsCharacterCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  var numberOfCharacters = 12.0;
  List<Character> randomCharacters = [];
  final GlobalKey<CharacterCircleComponentState> _characterCircleKey =
      GlobalKey<CharacterCircleComponentState>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    generateRandomCharacter(context);
  }

  void generateRandomCharacter(BuildContext context) {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    randomCharacters =
        characterService.getRandomCharacter(numberOfCharacters.toInt());
    characterService.getRandomCharacter(numberOfCharacters.toInt());
    gameStateService.initUnusedGameTokens(randomCharacters);
    gameStateService.addRandomUnusedTokensToRandomCharacters(randomCharacters);
    gameStateService.setIsLocked(false);
  }

  void updateNumberOfCharacters(double newValue) {
    setState(() {
      numberOfCharacters = newValue;
    });
    generateRandomCharacter(context);
  }

  void refreshCharacterCircle() {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    gameStateService.setIsLocked(false);
    _characterCircleKey.currentState?.initializeCharacterPositions();
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    var localizedStrings = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizedStrings.layoutSettings,
            style: TextStyle(color: Colors.white)),
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
          // Character Circle Component
          if (randomCharacters.isNotEmpty) ...[
            CharacterCircleComponent(
              key: _characterCircleKey,
              settingsView: true,
              characters: randomCharacters,
              charactersForToken: randomCharacters,
            ),
          ],
          // Immer sichtbarer Dialog
          Padding(
            padding:
                const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 64),
            child: Center(
              child: Container(
                width: 300,
                height: 750,
                child: _buildSettingsDialog(context, settingsService),
              ),
            ),
          ),
        ],
      ),
    );
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
                  settingsService.setCharacterKnobSize(newValue);
                },
                helpText: 'Adjust the size of the character knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.numberPerRow,
                value: settingsService.startAngleDiv.toDouble(),
                min: 2,
                max: 5,
                onChanged: (newValue) {
                  settingsService.setStartAngleDiv(newValue);
                },
                helpText: 'Adjust the starting angle of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.distanceX,
                value: settingsService.radiusX,
                min: 5,
                max: 109,
                onChanged: (newValue) {
                  settingsService.setRadiusX(newValue);
                },
                helpText: 'Adjust the horizontal radius of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.distanceY,
                value: settingsService.radiusY,
                min: 30,
                max: 235,
                onChanged: (newValue) {
                  settingsService.setRadiusY(newValue);
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
                  settingsService.setTokenKnobSize(newValue);
                },
                helpText: 'Adjust the size of the token knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.tokenOffsetX,
                value: settingsService.tokenOffsetX,
                min: -35,
                max: 70,
                onChanged: (newValue) {
                  settingsService.setTokenOffsetX(newValue);
                },
                helpText: 'Adjust the size of the token knob.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.tokenOffsetY,
                value: settingsService.tokenOffsetY,
                min: -40,
                max: 80,
                onChanged: (newValue) {
                  settingsService.setTokenOffsetY(newValue);
                },
                helpText: 'Adjust the size of the token knob.',
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
                  settingsService.setOffsetX(newValue);
                },
                helpText: 'Adjust the X-axis offset of the circle.',
              ),
              _buildSliderWithHelp(
                title: localizedStrings.containerOffsetY,
                value: settingsService.offsetY,
                min: -185,
                max: 25,
                onChanged: (newValue) {
                  settingsService.setOffsetY(newValue);
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
                onChanged(newValue); // Bestehende Funktion aufrufen
                refreshCharacterCircle(); // Zusätzliche Funktion aufrufen
              },
            ),
          ),
        ],
      ),
    );
  }
}
