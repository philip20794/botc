import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/app_page_route.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/components/select_gameset.dart';
import 'package:blood_on_the_clocktower/custom_icons.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/all_characters_screen.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
import 'package:blood_on_the_clocktower/screens/show_characters_to_players.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/screens/statistics_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _SetupState { completed, available, locked }

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadedCharactersForLanguageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageService = Provider.of<LanguageService>(context);
    final languageCode = languageService.locale.languageCode;

    if (_loadedCharactersForLanguageCode == languageCode) return;
    _loadedCharactersForLanguageCode = languageCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<CharacterService>(context, listen: false)
          .loadAllCharactersFromJson(languageService.locale);
    });
  }

  void setPlayerName() {
    final gameStateService =
        Provider.of<GameStateService>(context, listen: false);
    final characterService =
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
    final strings = AppLocalizations.of(context)!;
    final gameStateService = Provider.of<GameStateService>(context);
    final characterService = Provider.of<CharacterService>(context);
    final gameIsRunning = gameStateService.nightCount > -1;
    final playerDone = gameStateService.playerNames.length > 5;
    final characterDone = gameStateService.characterSelectionDone;
    final revealDone = gameStateService.charactersWhereShownToPlayers;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: GrimoireBackgroundVeil()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight - 34,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(strings),
                        const SizedBox(height: 12),
                        _buildCharacterOverview(strings),
                        const SizedBox(height: 12),
                        _buildScriptPanel(strings, gameIsRunning),
                        const SizedBox(height: 16),
                        GrimoireSectionHeading(
                          title: strings.gamePreparation,
                          icon: Icons.auto_stories_outlined,
                        ),
                        const SizedBox(height: 8),
                        GrimoirePanel(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            children: [
                              _SetupStepTile(
                                step: 1,
                                title: strings.players,
                                subtitle: strings.setupPlayersHint,
                                icon: Icons.groups,
                                state: gameIsRunning
                                    ? _SetupState.locked
                                    : playerDone
                                        ? _SetupState.completed
                                        : _SetupState.available,
                                onTap: () => gameIsRunning
                                    ? _showRunningGameDialog()
                                    : _openScreen(PlayernameScreen()),
                              ),
                              _SetupStepTile(
                                step: 2,
                                title: strings.characterSelection,
                                subtitle: strings.setupCharactersHint,
                                icon: Icons.dashboard_outlined,
                                state: gameIsRunning
                                    ? _SetupState.locked
                                    : characterDone
                                        ? _SetupState.completed
                                        : _SetupState.available,
                                onTap: () => gameIsRunning
                                    ? _showRunningGameDialog()
                                    : _openScreen(CharacterAuswahlScreen()),
                              ),
                              _SetupStepTile(
                                step: 3,
                                title: strings.showCharactersToPlayers,
                                subtitle: strings.setupRevealHint,
                                icon: Icons.visibility_outlined,
                                state: revealDone
                                    ? _SetupState.completed
                                    : _SetupState.available,
                                onTap: () async {
                                  if (!gameIsRunning) _shuffleCharacters();
                                  await _openScreen(ShowCharactersToPlayers());
                                },
                              ),
                              _SetupStepTile(
                                step: 4,
                                title: strings.playground,
                                subtitle: strings.setupPlaygroundHint,
                                icon: Icons.play_arrow_rounded,
                                state: gameIsRunning
                                    ? _SetupState.completed
                                    : _SetupState.available,
                                primary: true,
                                isLast: true,
                                onTap: () async {
                                  if (!gameIsRunning) {
                                    await gameStateService.startNewGame(
                                      characterService
                                          .gameCharactersWithoutDrunkAndFabled,
                                      completeSetupCharacters:
                                          characterService.gameCharacters,
                                      scriptCatalog:
                                          characterService.allCharacters,
                                    );
                                  }
                                  await _openScreen(
                                    Theme(
                                      data: GrimoireTheme.playground(),
                                      child: SpielbereichScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations strings) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GrimoireColors.surface.withValues(alpha: 0.90),
            border: Border.all(
              color: GrimoireColors.antiqueGold.withValues(alpha: 0.72),
            ),
          ),
          child: const Icon(
            Icons.auto_stories,
            color: GrimoireColors.antiqueGold,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.homeGrimoireTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: GrimoireColors.antiqueGold,
                      height: 1.05,
                    ),
              ),
              Text(
                strings.homeGrimoireSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('homeStatisticsButton'),
          tooltip: strings.statistics,
          onPressed: () => _openScreen(const StatisticsScreen()),
          icon: const Icon(Icons.bar_chart_rounded),
          color: GrimoireColors.ivory,
        ),
        IconButton(
          key: const ValueKey('homeSettingsButton'),
          tooltip: strings.settings,
          onPressed: () => _openScreen(AppSettingsScreen()),
          icon: const Icon(Icons.settings),
          color: GrimoireColors.ivory,
        ),
      ],
    );
  }

  Widget _buildCharacterOverview(AppLocalizations strings) {
    return OutlinedButton.icon(
      key: const ValueKey('homeCharacterOverviewButton'),
      onPressed: () => _openScreen(AllCharactersScreen()),
      icon: const Icon(Icons.menu_book_outlined, size: 20),
      label: Text(
        strings.allCharacters,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildScriptPanel(AppLocalizations strings, bool gameIsRunning) {
    return GrimoirePanel(
      emphasized: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CustomIcons.script,
                color: GrimoireColors.antiqueGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.selectedScript.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: GrimoireColors.secondaryText,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: SelectGameset(
                    disabled: gameIsRunning,
                    scriptWidth: constraints.maxWidth - 48,
                    showManagementAction: false,
                  ),
                ),
                SelectGameset(
                  disabled: gameIsRunning,
                  showSelector: false,
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: ScriptComplexitySummary(iconSize: 21, showLabels: true),
          ),
        ],
      ),
    );
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      AppPageRoute(builder: (_) => screen),
    );
  }

  void _showRunningGameDialog() {
    final strings = AppLocalizations.of(context)!;
    String? winningTeam;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.gameInProgress),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.endRunningGameToContinue),
              const SizedBox(height: 16),
              Text(
                strings.winningTeamOptional,
                style: const TextStyle(color: GrimoireColors.secondaryText),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildWinningTeamOption(
                      icon: Icons.shield_rounded,
                      label: strings.goodTeam,
                      color: GrimoireColors.antiqueGold,
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
                      label: strings.evilTeam,
                      color: GrimoireColors.crimson,
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
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _endRunningGame(winningTeam);
              },
              child: Text(strings.yesEndGame),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : GrimoireColors.background.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : GrimoireColors.antiqueGold.withValues(alpha: 0.22),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStepTile extends StatelessWidget {
  const _SetupStepTile({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    required this.onTap,
    this.primary = false,
    this.isLast = false,
  });

  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final _SetupState state;
  final VoidCallback onTap;
  final bool primary;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final stateColor = switch (state) {
      _SetupState.completed => GrimoireColors.antiqueGold,
      _SetupState.available => GrimoireColors.ivory,
      _SetupState.locked => GrimoireColors.disabled,
    };
    final stateLabel = switch (state) {
      _SetupState.completed => strings.setupCompleted,
      _SetupState.available => strings.setupAvailable,
      _SetupState.locked => strings.setupLocked,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state == _SetupState.completed
                        ? GrimoireColors.antiqueGold
                        : GrimoireColors.background.withValues(alpha: 0.88),
                    border: Border.all(color: stateColor, width: 1.2),
                  ),
                  child: state == _SetupState.completed
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: GrimoireColors.background,
                        )
                      : state == _SetupState.locked
                          ? const Icon(Icons.lock_outline, size: 14)
                          : Text(
                              '$step',
                              style: TextStyle(
                                color: stateColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: GrimoireColors.antiqueGold.withValues(alpha: 0.26),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
              child: Material(
                color: primary
                    ? GrimoireColors.antiqueGold
                    : GrimoireColors.background.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: primary ? 27 : 23,
                            color: primary
                                ? GrimoireColors.background
                                : stateColor,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: primary
                                            ? GrimoireColors.background
                                            : stateColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: primary
                                            ? GrimoireColors.background
                                                .withValues(alpha: 0.78)
                                            : GrimoireColors.secondaryText,
                                        height: 1.15,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                stateLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: primary
                                          ? GrimoireColors.background
                                          : stateColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: primary
                                    ? GrimoireColors.background
                                    : stateColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
