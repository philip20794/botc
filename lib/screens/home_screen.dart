import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/screens/all_characters_screen.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_screen.dart';
import 'package:blood_on_the_clocktower/screens/show_characters_to_players.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadedCharactersForLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageService = Provider.of<LanguageService>(context);
    final languageCode = languageService.locale.languageCode;

    if (_loadedCharactersForLanguageCode == languageCode) {
      return;
    }

    _loadedCharactersForLanguageCode = languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Provider.of<CharacterService>(context, listen: false)
          .loadAllCharactersFromJson(languageService.locale);
    });
  }

  void setPlayerName() {
    GameStateService gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    CharacterService characterService =
        Provider.of<CharacterService>(context, listen: false);
    characterService.syncPlayerNames(gameStateService.playerNames);
  }

  void _shuffleCharacters() {
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    gameStateService.reset(characterService.gameCharactersBackup);
    characterService.shuffelCharacters();
    setPlayerName();
  }

  @override
  Widget build(BuildContext context) {
    var localizedStrings = AppLocalizations.of(context)!;
    final gameStateService = Provider.of<GameStateService>(context);
    final characterService = Provider.of<CharacterService>(context);

    var gameIsRunning = gameStateService.nightCount > -1;
    var playerDone = gameStateService.playerNames.length > 5;
    var characterDone = gameStateService.characterSelectionDone;
    var showCharactersToPlayersDone =
        gameStateService.charactersWhereShownToPlayers;
    var allDone = characterDone && showCharactersToPlayersDone;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    'assets/images/backgrounds/background_grim_full.jpg'), // Path to your background image
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
                  // Keep the first card clear of the persistent settings
                  // control in the top-right safe area.
                  const SizedBox(height: 88),
                  _buildCard(localizedStrings.allCharacters, Icons.list_alt,
                      AllCharactersScreen(), false, null),
                  SizedBox(height: 50),
                  Card(
                    color: const Color(0xFF6f678a).withOpacity(0.9),
                    margin: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 20),
                    child: ListTile(
                      leading: Icon(CustomIcons.script,
                          color: gameIsRunning ? Colors.grey : Colors.white),
                      title: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectGameset(disabled: gameIsRunning),
                          const SizedBox(height: 4),
                          const ScriptComplexitySummary(),
                        ],
                      ),
                    ),
                  ),
                  _buildArrowDown(gameIsRunning),
                  _buildCard(localizedStrings.players, Icons.groups,
                      PlayernameScreen(), gameIsRunning, null),
                  SizedBox(height: 16),
                  _buildCard(
                      localizedStrings.roleNotes,
                      Icons.manage_search,
                      RoleNotesScreen(),
                      gameStateService.playerNames.isEmpty,
                      null),
                  SizedBox(height: 16),
                  _buildArrowDown(!playerDone || gameIsRunning),
                  _buildCard(
                      localizedStrings.characterSelection,
                      Icons.dashboard,
                      CharacterAuswahlScreen(),
                      gameIsRunning,
                      null),
                  _buildArrowDown(false),
                  _buildCard(
                      localizedStrings.showCharactersToPlayers,
                      Icons.remove_red_eye,
                      ShowCharactersToPlayers(),
                      false,
                      () => {
                            if (!gameIsRunning) {_shuffleCharacters()}
                          }),
                  _buildArrowDown(!allDone),
                  _buildCard(
                      localizedStrings.playground,
                      Icons.play_arrow,
                      SpielbereichScreen(),
                      false,
                      () => {
                            if (!gameIsRunning)
                              {
                                gameStateService.startNewGame(
                                    characterService.gameCharactersWithoutDrunk)
                              }
                          }),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // This must be painted last so neither the scrollable cards nor
          // their gesture detectors can cover the settings control.
          _buildIconButton(Icons.settings, AppSettingsScreen()),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Widget onTap) {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 8, right: 8),
        child: IconButton(
          key: const ValueKey('homeSettingsButton'),
          icon: Icon(icon),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => onTap),
            );
          },
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildArrowDown(bool disabled) {
    return Center(
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.arrow_downward,
            color: disabled ? Colors.grey : Colors.white, size: 30),
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, Widget onTap, bool disabled,
      Function? function) {
    return Card(
      color: const Color(0xFF6f678a).withOpacity(0.9),
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
      child: ListTile(
        leading: Icon(icon, color: disabled ? Colors.grey : Colors.white),
        title: Center(
            child: Text(title,
                style:
                    TextStyle(color: disabled ? Colors.grey : Colors.white))),
        onTap: () {
          if (disabled) {
            return;
          }
          if (function != null) {
            function();
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => onTap),
          );
        },
      ),
    );
  }
}
