import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';

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
              backgroundColor: Color(0xFF4a3b5e).withOpacity(0.9),
              title: Text(localizedStrings.playerAlreadyExists,
                  style: TextStyle(color: Colors.white)),
              content: Text(
                  localizedStrings.playerWithNameAlreadyExists(playerName),
                  style: TextStyle(color: Colors.white)),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(localizedStrings.players,
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
          Padding(
            padding:
                const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 64),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  cursorColor: Colors.white,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: localizedStrings.playerName,
                    labelStyle: TextStyle(color: Colors.white),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add, color: Colors.white),
                      onPressed: _addPlayer,
                    ),
                  ),
                  onSubmitted: (value) => _addPlayer(),
                ),
                SizedBox(height: 20),
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
                                        padding:
                                            const EdgeInsets.only(bottom: 4.0),
                                        child: SizedBox(
                                          height: 50,
                                          key: ValueKey(player),
                                          child: Container(
                                            key: ValueKey(player),
                                            color: Color(0xFF4a3b5e)
                                                .withOpacity(0.5),
                                            child: ListTile(
                                              tileColor:
                                                  Colors.black.withOpacity(0.5),
                                              key: ValueKey(player),
                                              leading:
                                                  ReorderableDragStartListener(
                                                index: index,
                                                child: Icon(Icons.drag_handle,
                                                    color: Colors.white),
                                              ),
                                              title: Text(player,
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              trailing: IconButton(
                                                icon: Icon(Icons.delete,
                                                    color: Colors.white),
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
    );
  }
}
