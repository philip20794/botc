import 'dart:async';

import 'package:blood_on_the_clocktower/models/active_night_chronicle_input.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Compact optional Chronicle controls displayed below the phase information
/// button. Player selection itself happens on the board tokens.
class NightChronicleControls extends StatelessWidget {
  final ActiveNightChronicleInput input;
  final List<Character> gameCharacters;

  const NightChronicleControls({
    super.key,
    required this.input,
    required this.gameCharacters,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.read<GameStateService>();
    final groups = <Widget>[
      for (final field in input.yesNoFields) _yesNoButtons(gameState, field),
      for (final field in input.numberFields) _numberButtons(gameState, field),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: groups.indexed
              .expand(
                (entry) => [
                  if (entry.$1 > 0) const SizedBox(height: 4),
                  entry.$2,
                ],
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _yesNoButtons(
    GameStateService gameState,
    ChronicleInputDefinition field,
  ) {
    final value = input.values[field.id];
    return Tooltip(
      message: field.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _choiceButton(
            icon: Icons.thumb_up_alt_outlined,
            selected: value == true,
            onTap: () => unawaited(
              gameState.toggleNightChronicleYesNo(input, field, true),
            ),
          ),
          const SizedBox(width: 6),
          _choiceButton(
            icon: Icons.thumb_down_alt_outlined,
            selected: value == false,
            onTap: () => unawaited(
              gameState.toggleNightChronicleYesNo(input, field, false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberButtons(
    GameStateService gameState,
    ChronicleInputDefinition field,
  ) {
    final minimum = field.min ?? 0;
    final maximum = field.max ?? gameCharacters.length - 4;
    return Tooltip(
      message: field.label,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var value = minimum; value <= maximum; value++)
            _choiceButton(
              label: '$value',
              selected: input.values[field.id] == value,
              onTap: () => unawaited(
                gameState.toggleNightChronicleNumber(input, field, value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _choiceButton({
    IconData? icon,
    String? label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? const Color(0xFFD4AF67)
                : const Color(0xFF4A3B5E).withValues(alpha: 0.95),
            border: Border.all(
              color: selected ? Colors.white : Colors.white38,
              width: selected ? 2 : 1,
            ),
          ),
          child: icon == null
              ? Text(
                  label!,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.black : Colors.white,
                ),
        ),
      );
}
