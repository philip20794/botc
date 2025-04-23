import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectGameset extends StatefulWidget {
  final bool disabled;

  const SelectGameset({super.key, required this.disabled});

  @override
  _SelectGamesetState createState() => _SelectGamesetState();
}

class _SelectGamesetState extends State<SelectGameset> {
  @override
  Widget build(BuildContext context) {
    GameStateService gameStateService = Provider.of<GameStateService>(context);
    CharacterService characterService = Provider.of<CharacterService>(context);
    return DropdownButton<Gameset>(
      dropdownColor: const Color(0xFF6f678a),
      iconEnabledColor: Colors.white,
      value: gameStateService.gameset,
      underline: Container(), // Entfernt die standardmäßige Unterstreichung
      onChanged: (Gameset? newValue) {
        if (widget.disabled) return;
        setState(() {
          characterService.reset();
          gameStateService.setGameset(
              newValue!, characterService.gameCharacters);
        });
      },
      items: [
        DropdownMenuItem(
          value: Gameset.trouble_brewing,
          child: Text("Trouble Brewing",
              style: TextStyle(
                  color: widget.disabled ? Colors.grey : Colors.white)),
        ),
        DropdownMenuItem(
          value: Gameset.sects_and_violets,
          child: Text("Sects & Violets",
              style: TextStyle(
                  color: widget.disabled ? Colors.grey : Colors.white)),
        ),
        DropdownMenuItem(
          value: Gameset.bad_moon_rising,
          child: Text("Bad Moon Rising",
              style: TextStyle(
                  color: widget.disabled ? Colors.grey : Colors.white)),
        ),
        DropdownMenuItem(
          value: Gameset.experimental,
          child: Text("Experimental",
              style: TextStyle(
                  color: widget.disabled ? Colors.grey : Colors.white)),
        ),
      ],
    );
  }
}
