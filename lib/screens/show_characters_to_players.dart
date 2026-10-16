import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Player hand-off, private role reveal, and final Storyteller hand-off.
/// Only the current player can enter the reveal stage.
enum _PresentationStage { handoff, reveal, storyteller }

class ShowCharactersToPlayers extends StatefulWidget {
  const ShowCharactersToPlayers({super.key});

  @override
  State<ShowCharactersToPlayers> createState() =>
      _ShowCharactersToPlayersState();
}

class _ShowCharactersToPlayersState extends State<ShowCharactersToPlayers>
    with SingleTickerProviderStateMixin {
  static const _gold = GrimoireColors.antiqueGold;
  static const _ivory = GrimoireColors.ivory;
  static const _secondary = GrimoireColors.secondaryText;
  static const _violet = GrimoireColors.deepViolet;
  static const _holdDuration = Duration(milliseconds: 900);

  late final AnimationController _holdProgress;
  _PresentationStage _stage = _PresentationStage.handoff;
  int _currentCharacterIndex = 0;
  bool _isHolding = false;
  bool _roleVisible = false;
  bool _hasSeenRole = false;
  bool _startingGame = false;

  @override
  void initState() {
    super.initState();
    _holdProgress = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed ||
            !mounted ||
            _stage != _PresentationStage.reveal ||
            !_isHolding) {
          return;
        }
        setState(() {
          _roleVisible = true;
          _hasSeenRole = true;
        });
      });
  }

  @override
  void dispose() {
    _holdProgress.dispose();
    super.dispose();
  }

  bool get _isGerman => Localizations.localeOf(context).languageCode == 'de';

  String _tr(String german, String english) =>
      _isGerman ? german : english;

  // Do not start charging on a raw pointer-down: a tap must never reveal
  // a role. Both surfaces wait for Flutter's actual long-press recognition,
  // then show a visible 900ms charge before revealing anything private.
  void _beginHold() {
    if (_stage != _PresentationStage.reveal || _isHolding) return;
    _isHolding = true;
    _holdProgress.forward(from: 0);
  }

  void _endHold() {
    if (!_isHolding) return;
    _isHolding = false;
    // Cover the role immediately on release or gesture cancellation, even
    // if the animation did not finish yet.
    if (_roleVisible) setState(() => _roleVisible = false);
    _holdProgress.reset();
  }

  Widget _holdArea({required Key key, required Widget child}) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _beginHold(),
      onLongPressEnd: (_) => _endHold(),
      onLongPressCancel: _endHold,
      child: Semantics(
        label: _tr('Zum Enthüllen gedrückt halten', 'Hold to reveal'),
        child: child,
      ),
    );
  }

  void _openCharacter() {
    _holdProgress.reset();
    setState(() {
      _stage = _PresentationStage.reveal;
      _roleVisible = false;
      _hasSeenRole = false;
      _isHolding = false;
    });
  }

  void _nextPlayer() {
    if (!_hasSeenRole || _roleVisible || _isHolding) return;
    _holdProgress.reset();
    setState(() {
      _currentCharacterIndex++;
      _stage = _PresentationStage.handoff;
      _roleVisible = false;
      _hasSeenRole = false;
      _holdingPointer = null;
    });
  }

  Future<void> _startGame(
    BuildContext context,
    CharacterService characters,
    GameStateService game,
  ) async {
    if (_startingGame) return;
    setState(() => _startingGame = true);
    try {
      if (game.nightCount < 0) {
        await game.startNewGame(
          characters.gameCharactersWithoutDrunkAndFabled,
          completeSetupCharacters: characters.gameCharacters,
          scriptCatalog: characters.allCharacters,
        );
      }
      if (!context.mounted) return;
      // Prevent a player from returning to the private distribution flow.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => SpielbereichScreen()),
      );
    } finally {
      if (mounted) setState(() => _startingGame = false);
    }
  }

  Future<bool> _confirmBack() async {
    final strings = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.reallyWantToGoBack),
            content: Text(strings.onlyTheStorytellerMayGoBack),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.yesImTheStoryteller),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final characters = context.watch<CharacterService>();
    final game = context.read<GameStateService>();
    final roster = characters.gameCharactersWithoutDrunkAndFabled;
    final isStorytellerTurn = _currentCharacterIndex >= roster.length;
    final current = isStorytellerTurn ? null : roster[_currentCharacterIndex];

    if (isStorytellerTurn && !game.showCharactersToPlayers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) game.setShowCharactersToPlayers(true);
      });
    }

    return WillPopScope(
      onWillPop: _confirmBack,
      child: AppBackground(
        type: AppBackgroundType.playground,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: switch (_stage) {
                          _PresentationStage.handoff =>
                            _buildHandoff(current, roster.length),
                          _PresentationStage.reveal =>
                            current == null
                                ? _buildHandoff(null, roster.length)
                                : _buildReveal(current, roster.length),
                          _PresentationStage.storyteller =>
                            _buildStoryteller(context, characters, game),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eyebrow(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _gold,
          fontFamily: GrimoireTheme.headingFont,
          fontSize: 13,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _heading(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ivory,
          fontFamily: GrimoireTheme.headingFont,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      );

  Widget _hint(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _secondary, fontSize: 15, height: 1.4),
      );

  Widget _primaryButton({
    required Key key,
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text, textAlign: TextAlign.center),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: GrimoireColors.background,
          disabledBackgroundColor: _violet.withValues(alpha: 0.82),
          disabledForegroundColor: _secondary,
          textStyle: const TextStyle(
            fontFamily: GrimoireTheme.headingFont,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildHandoff(Character? character, int total) {
    final storyteller = character == null;
    final playerName = storyteller
        ? _tr('Spielleitung', 'Storyteller')
        : character.playerName.trim().isNotEmpty
            ? character.playerName
            : _tr('Spieler ${_currentCharacterIndex + 1}',
                'Player ${_currentCharacterIndex + 1}');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow(storyteller
            ? _tr('Alle Rollen verteilt', 'All roles distributed')
            : _tr('Spieler ${_currentCharacterIndex + 1} von $total',
                'Player ${_currentCharacterIndex + 1} of $total')),
        const SizedBox(height: 22),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GrimoireColors.surface.withValues(alpha: 0.88),
            border: Border.all(color: _gold.withValues(alpha: 0.55)),
          ),
          child: const Icon(Icons.phone_android_rounded, color: _gold, size: 48),
        ),
        const SizedBox(height: 24),
        _heading(_tr('Gib das Gerät an', 'Pass the device to')),
        const SizedBox(height: 8),
        Text(
          playerName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _gold,
            fontFamily: GrimoireTheme.headingFont,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        _hint(_tr(
          'Nur diese Person darf jetzt auf den Bildschirm schauen.',
          'Only this person should look at the screen now.',
        )),
        const SizedBox(height: 30),
        _primaryButton(
          key: const ValueKey('role-handoff-confirm'),
          icon: Icons.arrow_forward_rounded,
          text: storyteller
              ? _tr('Ich bin die Spielleitung', 'I am the Storyteller')
              : _tr('Ich bin $playerName', 'I am $playerName'),
          onPressed: storyteller
              ? () => setState(() => _stage = _PresentationStage.storyteller)
              : _openCharacter,
        ),
      ],
    );
  }

  Widget _buildReveal(Character character, int total) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow(_tr('Spieler ${_currentCharacterIndex + 1} von $total',
            'Player ${_currentCharacterIndex + 1} of $total')),
        const SizedBox(height: 14),
        _heading('${AppLocalizations.of(context)!.characterOf} '
            '${character.playerName}'),
        const SizedBox(height: 22),
        _holdArea(
          key: const ValueKey('role-reveal-eye'),
          child: AnimatedBuilder(
            animation: _holdProgress,
            builder: (context, _) => Container(
              width: 196,
              height: 196,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(
                        alpha: _holdProgress.value * 0.32),
                    blurRadius: 12 + _holdProgress.value * 18,
                    spreadRadius: _holdProgress.value * 2,
                  ),
                ],
                border: Border.all(
                  color: _gold.withValues(
                      alpha: 0.32 + _holdProgress.value * 0.65),
                  width: 2,
                ),
              ),
              child: _roleVisible
                  ? CharacterAvatar(
                      character: character,
                      showIsSelected: false,
                      showName: true,
                      size: 192,
                    )
                  : const CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(
                        'assets/images/backgrounds/token.png',
                      ),
                      child: Icon(
                        Icons.remove_red_eye_rounded,
                        size: 74,
                        color: GrimoireColors.background,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 74,
          child: Center(
            child: AutoSizeText(
              _roleVisible
                  ? character.descriptionShort
                  : _tr('Auge oder Button gedrückt halten',
                      'Press and hold the eye or button'),
              textAlign: TextAlign.center,
              maxLines: 3,
              minFontSize: 11,
              maxFontSize: 15,
              style: const TextStyle(
                color: _secondary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        _holdArea(
          key: const ValueKey('role-reveal-hold-button'),
          child: LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: _holdProgress,
              builder: (context, _) {
                // FractionallySizedBox in a loosely constrained Align can
                // end up with no visible width. Use the actual button width
                // for a reliably painted gold fill on Android and web.
                final chargedWidth =
                    constraints.maxWidth * _holdProgress.value;
                return Container(
                  width: constraints.maxWidth,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.75),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: chargedWidth,
                        child: DecoratedBox(
                          key: const ValueKey('role-reveal-progress-fill'),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.visibility_rounded,
                            color: _ivory,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 3),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _tr('Charakter anzeigen', 'Reveal character'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _ivory,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                                fontFamily: GrimoireTheme.headingFont,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        height: 5,
                        width: chargedWidth,
                        child: const ColoredBox(color: _gold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        _primaryButton(
          key: const ValueKey('role-reveal-continue'),
          icon: Icons.check_rounded,
          text: _tr('Fertig – weitergeben', 'Done – pass it on'),
          onPressed: _hasSeenRole && !_roleVisible && !_isHolding
              ? _nextPlayer
              : null,
        ),
        const SizedBox(height: 12),
        _hint(_hasSeenRole
            ? _tr('Deine Rolle wird beim Loslassen wieder verdeckt.',
                'Your role is hidden again when you release.')
            : _tr('Halte gedrückt, bis sich der Button ganz gefüllt hat.',
                'Keep holding until the button is fully filled.')),
      ],
    );
  }

  Widget _buildStoryteller(
    BuildContext context,
    CharacterService characters,
    GameStateService game,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _eyebrow(_tr('Rollenverteilung abgeschlossen',
            'Role distribution complete')),
        const SizedBox(height: 24),
        Container(
          height: 108,
          width: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GrimoireColors.surface.withValues(alpha: 0.92),
            border: Border.all(color: _gold.withValues(alpha: 0.65)),
          ),
          child: const Icon(Icons.menu_book_rounded, size: 52, color: _gold),
        ),
        const SizedBox(height: 26),
        _heading(AppLocalizations.of(context)!.onlyForTheStoryteller),
        const SizedBox(height: 16),
        _hint(_tr(
          'Alle Spieler haben ihre geheime Rolle erhalten. Du kannst das Spiel jetzt starten.',
          'All players have received their secret role. You can now start the game.',
        )),
        const SizedBox(height: 32),
        _primaryButton(
          key: const ValueKey('role-storyteller-start'),
          icon: Icons.play_arrow_rounded,
          text: AppLocalizations.of(context)!.startGame,
          onPressed: _startingGame
              ? null
              : () => _startGame(context, characters, game),
        ),
      ],
    );
  }
}
