import 'package:blood_on_the_clocktower/components/night_chronicle_controls.dart';
import 'package:blood_on_the_clocktower/models/active_night_chronicle_input.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character _owner() => Character(
      id: 'chef',
      roleId: 'chef',
      name: 'Chef',
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_chef',
      fraction: Fraction.townsfolk,
      tokens: const [],
      wakeUpEveryNight: false,
      wakeUpAtFirstNight: false,
      gameset: const [],
      nightStateNumbersFirstNight: const [],
      nightStateNumbersOtherNights: const [],
      tipsAndTricks: const [],
      bluffs: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('playground Chronicle number controls honor a configured maximum',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final gameState = GameStateService();
    await gameState.ready;
    final owner = _owner();
    final numberField = ChronicleInputDefinition(
      id: 'count',
      type: ChronicleInputType.number,
      label: 'Count',
      min: 0,
      max: 4,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: gameState,
        child: MaterialApp(
          home: Scaffold(
            body: NightChronicleControls(
              gameCharacters: List.filled(13, owner),
              input: ActiveNightChronicleInput(
                owner: owner,
                definition: numberField,
                eventId: null,
                values: const {},
              ),
            ),
          ),
        ),
      ),
    );

    for (final value in [0, 1, 2, 3, 4]) {
      expect(find.text('$value'), findsOneWidget);
    }
    expect(find.text('5'), findsNothing);
    expect(find.text('13'), findsNothing);
  });
}
