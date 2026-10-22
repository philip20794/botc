import 'package:blood_on_the_clocktower/components/character_circle_component.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';

class SettingsCharacterCircle extends StatefulWidget {
  @override
  _SettingsCharacterCircleState createState() =>
      _SettingsCharacterCircleState();
}

class _SettingsCharacterCircleState extends State<SettingsCharacterCircle> {
  var numberOfCharacters = 11.0;
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
    var localizedStrings = AppLocalizations.of(context)!;
    final previewTokens = _previewTokens(characterService);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, -78),
                child: _ReminderTokenSizePreview(
                  selectedSize: settingsService.selectedReminderTokenSize,
                  unselectedSize: settingsService.unselectedReminderTokenSize,
                  selectedLabel: localizedStrings.selectedReminderSize,
                  unselectedLabel: localizedStrings.unselectedReminderSize,
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
                      icon: const Icon(Icons.arrow_back,
                          color: GrimoireColors.ivory),
                    ),
                    Text(
                      localizedStrings.layoutSettings,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: GrimoireColors.ivory,
                          ),
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
                    width: MediaQuery.sizeOf(context).width.clamp(0, 360),
                    height: MediaQuery.sizeOf(context).height * 0.78,
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
    return GrimoirePanel(
      emphasized: true,
      // Keep the live circle preview visible while editing layout values.
      surfaceOpacity: 0.66,
      padding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: EdgeInsets.zero,
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
                persistOnEnd: false,
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
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  key: const ValueKey('layout-settings-reset-defaults'),
                  onPressed: () async {
                    await settingsService.resetSettings();
                    if (!mounted) return;
                    setState(() {
                      updateNumberOfCharacters(11);
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: Text(localizedStrings.resetLayoutDefaults),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GrimoireColors.ivory,
                    side: const BorderSide(color: GrimoireColors.antiqueGold),
                  ),
                ),
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
    bool persistOnEnd = true,
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
                if (persistOnEnd) {
                  Provider.of<SettingsService>(context, listen: false)
                      .saveSettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTokenSizePreview extends StatelessWidget {
  const _ReminderTokenSizePreview({
    required this.selectedSize,
    required this.unselectedSize,
    required this.selectedLabel,
    required this.unselectedLabel,
  });

  final double selectedSize;
  final double unselectedSize;
  final String selectedLabel;
  final String unselectedLabel;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: '$selectedLabel / $unselectedLabel',
        child: Row(
          key: const ValueKey('layout-settings-reminder-token-preview'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ReminderTokenPreviewCard(
              key: const ValueKey('layout-settings-selected-reminder-preview'),
              size: selectedSize,
              selected: true,
            ),
            const SizedBox(width: 8),
            _ReminderTokenPreviewCard(
              key:
                  const ValueKey('layout-settings-unselected-reminder-preview'),
              size: unselectedSize,
              selected: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTokenPreviewCard extends StatelessWidget {
  const _ReminderTokenPreviewCard({
    super.key,
    required this.size,
    required this.selected,
  });

  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size * 1.15,
      decoration: BoxDecoration(
        color: GrimoireColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? GrimoireColors.antiqueGold : GrimoireColors.deepViolet,
          width: selected ? 3 : 1.5,
        ),
      ),
      child: Icon(
        selected ? Icons.check : Icons.more_horiz,
        color: GrimoireColors.ivory,
        size: size * 0.55,
      ),
    );
  }
}
