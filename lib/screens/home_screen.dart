import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/screens/all_characters_screen.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
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

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
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
                        leading: SizedBox(
                          width: 40,
                          child: Center(
                            child: Icon(CustomIcons.script,
                                color:
                                    gameIsRunning ? Colors.grey : Colors.white),
                          ),
                        ),
                        trailing: SizedBox(
                          width: 48,
                          child: Center(
                            child: SelectGameset(
                              disabled: gameIsRunning,
                              showSelector: false,
                            ),
                          ),
                        ),
                        title: LayoutBuilder(
                          builder: (context, constraints) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectGameset(
                                disabled: gameIsRunning,
                                scriptWidth: constraints.maxWidth,
                                showManagementAction: false,
                              ),
                              const SizedBox(height: 4),
                              const ScriptComplexitySummary(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildArrowDown(gameIsRunning),
                    _buildCard(localizedStrings.players, Icons.groups,
                        PlayernameScreen(), gameIsRunning, null,
                        onDisabledTap:
                            gameIsRunning ? _showRunningGameDialog : null),
                    _buildArrowDown(!playerDone || gameIsRunning),
                    _buildCard(
                        localizedStrings.characterSelection,
                        Icons.dashboard,
                        CharacterAuswahlScreen(),
                        gameIsRunning,
                        null,
                        onDisabledTap:
                            gameIsRunning ? _showRunningGameDialog : null),
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
                    _buildCard(localizedStrings.playground, Icons.play_arrow,
                        SpielbereichScreen(), false, () async {
                      if (!gameIsRunning) {
                        await gameStateService.startNewGame(
                          characterService.gameCharactersWithoutDrunkAndFabled,
                          completeSetupCharacters:
                              characterService.gameCharacters,
                          scriptCatalog: characterService.allCharacters,
                        );
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
      Function? function,
      {VoidCallback? onDisabledTap}) {
    return Card(
      color: const Color(0xFF6f678a).withOpacity(0.9),
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
      child: ListTile(
        leading: Icon(icon, color: disabled ? Colors.grey : Colors.white),
        title: Center(
            child: Text(title,
                style:
                    TextStyle(color: disabled ? Colors.grey : Colors.white))),
        onTap: () async {
          if (disabled) {
            onDisabledTap?.call();
            return;
          }
          if (function != null) {
            await function();
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => onTap),
          );
        },
      ),
    );
  }

  void _showRunningGameDialog() {
    final localizedStrings = AppLocalizations.of(context)!;
    String? winningTeam;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF4a3b5e).withOpacity(0.94),
          title: Text(
            localizedStrings.gameInProgress,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizedStrings.endRunningGameToContinue,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 18),
              Text(
                localizedStrings.winningTeamOptional,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildWinningTeamOption(
                      icon: Icons.shield_rounded,
                      label: localizedStrings.goodTeam,
                      color: const Color(0xFF4CA8FF),
                      isSelected: winningTeam == 'good',
                      onTap: () => setDialogState(() {
                        winningTeam = winningTeam == 'good' ? null : 'good';
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildWinningTeamOption(
                      icon: Icons.local_fire_department_rounded,
                      label: localizedStrings.evilTeam,
                      color: const Color(0xFFFF5A5F),
                      isSelected: winningTeam == 'evil',
                      onTap: () => setDialogState(() {
                        winningTeam = winningTeam == 'evil' ? null : 'evil';
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                localizedStrings.cancel,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _endRunningGame(winningTeam);
              },
              child: Text(
                localizedStrings.yesEndGame,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endRunningGame(String? winningTeam) async {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    await gameStateService.endGame(
      winningTeam: winningTeam,
      characterService: characterService,
    );
    if (mounted) setState(() {});
  }

  Widget _buildWinningTeamOption({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.30) : Colors.black26,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.white24,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
}
