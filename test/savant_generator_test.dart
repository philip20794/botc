import 'package:blood_on_the_clocktower/components/savant_generator.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Character role(String roleId, Fraction fraction) => Character(
        id: roleId,
        roleId: roleId,
        name: roleId,
        descriptionShort: '',
        descriptionLong: '',
        howToRun: '',
        image: 'Icon_$roleId',
        fraction: fraction,
        tokens: const [],
        wakeUpEveryNight: false,
        wakeUpAtFirstNight: false,
        gameset: const [Gameset.trouble_brewing],
        nightStateNumbersFirstNight: const [],
        nightStateNumbersOtherNights: const [],
        tipsAndTricks: const [],
        bluffs: const [],
      );

  testWidgets('does not call setState during build or crash with empty inputs',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;
    final game = GameStateService(scriptService: scripts);
    await game.ready;
    final characters = CharacterService();
    await characters.init();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: scripts),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: characters),
      ],
      child: const MaterialApp(home: SavantGenerator()),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('No Savant statement available.'), findsOneWidget);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('generates a statement when players and roles are available',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;
    final game = GameStateService(scriptService: scripts);
    await game.ready;
    await game.addPlayerName('Alice');
    final characters = CharacterService();
    await characters.init();
    characters.allCharacters.addAll([
      role('monk', Fraction.townsfolk),
      role('imp', Fraction.demon),
      role('poisoner', Fraction.minion),
    ]);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: scripts),
        ChangeNotifierProvider.value(value: game),
        ChangeNotifierProvider.value(value: characters),
      ],
      child: const MaterialApp(home: SavantGenerator()),
    ));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('['), findsNothing);
  });
}
