import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';

class PlayernameScreen extends StatefulWidget {
  @override
  _PlayernameScreenState createState() => _PlayernameScreenState();
}

class _PlayernameScreenState extends State<PlayernameScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _addPlayer() {
    var localizedStrings = AppLocalizations.of(context)!;
    final gameStatusService =
        Provider.of<GameStateService>(context, listen: false);
    final playerName = _nameController.text.trim();

    var playerAllreadyExists =
        gameStatusService.playerNames.contains(playerName);

    if (playerName.isNotEmpty && !playerAllreadyExists) {
      setState(() {
        gameStatusService.addPlayerName(playerName);
      });
      _nameController.clear();
    } else {
      if (playerAllreadyExists) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(localizedStrings.playerAlreadyExists,
                  style: const TextStyle(color: GrimoireColors.ivory)),
              content: Text(
                  localizedStrings.playerWithNameAlreadyExists(playerName),
                  style: const TextStyle(color: GrimoireColors.ivory)),
            );
          },
        );
      }
    }
  }

  void _removePlayer(String playerName) {
    final gameStatusService =
        Provider.of<GameStateService>(context, listen: false);
    setState(() {
      gameStatusService.removePlayerName(playerName);
    });
  }

  // Methode zum Neuanordnen der Elemente
  void _reorderPlayers(int oldIndex, int newIndex) {
    final gameStatusService =
        Provider.of<GameStateService>(context, listen: false);
    setState(() {
      gameStatusService.reorderPlayerNames(oldIndex, newIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameStatusService = Provider.of<GameStateService>(context);
    var localizedStrings = AppLocalizations.of(context)!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(localizedStrings.players,
              style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 16, left: 16, right: 16, bottom: 64),
              child: Column(
                children: [
                  GrimoirePanel(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      cursorColor: GrimoireColors.antiqueGold,
                      style: const TextStyle(color: GrimoireColors.ivory),
                      decoration: InputDecoration(
                        labelText: localizedStrings.playerName,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add,
                              color: GrimoireColors.antiqueGold),
                          onPressed: _addPlayer,
                        ),
                      ),
                      onSubmitted: (value) => _addPlayer(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: gameStatusService.playerNames.isEmpty
                        ? Center(
                            child: Text(localizedStrings.noPlayerYet,
                                style: TextStyle(color: Colors.white)))
                        : ReorderableListView(
                            proxyDecorator: (widget, index, animation) {
                              return Material(
                                child: widget,
                                color: Colors.transparent,
                              );
                            },
                            onReorder: _reorderPlayers,
                            children: gameStatusService.playerNames
                                .asMap()
                                .map((index, player) => MapEntry(
                                      index,
                                      Padding(
                                          key: ValueKey(player),
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: SizedBox(
                                            height: 50,
                                            key: ValueKey(player),
                                            child: AnimatedContainer(
                                              duration: MediaQuery.disableAnimationsOf(context)
                                                  ? Duration.zero
                                                  : const Duration(milliseconds: 180),
                                              key: ValueKey(player),
                                              decoration: GrimoireTheme.panelDecoration(),
                                              child: ListTile(
                                                key: ValueKey(player),
                                                leading:
                                                    ReorderableDragStartListener(
                                                  index: index,
                                                  child: Icon(Icons.drag_handle,
                                                      color: GrimoireColors.secondaryText),
                                                ),
                                                title: Text(player,
                                                    style: const TextStyle(
                                                        color: GrimoireColors.ivory)),
                                                trailing: IconButton(
                                                  icon: Icon(Icons.delete,
                                                      color: GrimoireColors.secondaryText),
                                                  onPressed: () =>
                                                      _removePlayer(player),
                                                ),
                                              ),
                                            ),
                                          )),
                                    ))
                                .values
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
            NextScreenFooter(
              nextScreen: CharacterAuswahlScreen(),
              nextScreenName: localizedStrings.characterSelection,
              nextScreenIcon: Icons.dashboard,
              currentScreenName: localizedStrings.players,
              disabled: gameStatusService.playerNames.length < 5,
            ),
          ],
        ),
      ),
    );
  }
}
