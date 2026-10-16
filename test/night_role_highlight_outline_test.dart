import 'dart:convert';

import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> catalog;

  setUpAll(() async {
    catalog = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Character characterFor(String roleId) {
    final entry = catalog.singleWhere((item) => item['roleId'] == roleId);
    return Character.fromJson({
      ...entry,
      'id': 'instance-$roleId',
      'playerName': 'Player $roleId',
    });
  }

  Future<GameStateService> runningGame(
      WidgetTester tester, List<Character> characters) async {
    late GameStateService game;
    await tester.runAsync(() async {
      final script = ScriptService();
      final order = NightOrderService();
      await Future.wait([script.ready, order.ready]);
      game = GameStateService(
        scriptService: script,
        nightOrderService: order,
      );
      await game.ready;
      await game.startNewGame(characters);
    });
    return game;
  }

  Future<void> advanceTo(
      WidgetTester tester,
      GameStateService game,
      List<Character> characters,
      String stepId) async {
    // Night navigation also saves position; keep asynchronous storage writes
    // out of the widget-test fake-async clock.
    await tester.runAsync(() async {
      for (var i = 0; i < 180 && game.currentNightStepId != stepId; i++) {
        await game.nextNightState(characters);
      }
    });
    expect(game.currentNightStepId, stepId);
    await tester.pump();
  }

  testWidgets('Fortune Teller has a visible white ring in both nights',
      (tester) async {
    final roles = [characterFor('fortuneteller')];
    final game = await runningGame(tester, roles);
    await tester.pumpWidget(
      ChangeNotifierProvider<GameStateService>.value(
        value: game,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: CharacterAvatar(
                character: roles.single,
                showIsSelected: true,
                showName: false,
                size: 112,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const ringKey = ValueKey('character-avatar-highlight-outline');
    expect(find.byKey(ringKey), findsNothing);

    for (final night in [1, 2]) {
      await advanceTo(tester, game, roles,
          'role:fortuneteller:instance-fortuneteller');
      expect(game.nightCount, night);
      expect(game.isCharacterAwake(roles.single), isTrue);
      expect(game.isCharacterHighlighted(roles.single), isTrue);
      expect(find.byKey(ringKey), findsOneWidget);

      // The highlight is the final paint layer over the art (not a ring
      // underneath the icon where its opaque pixels may hide it).
      final stack = tester.widget<Stack>(
        find.byKey(const ValueKey('character-avatar-artwork-stack')),
      );
      final ringPosition = stack.children.last as Positioned;
      final ignorePointer = ringPosition.child as IgnorePointer;
      final ring = ignorePointer.child as Container;
      expect(ring.key, ringKey);
      final decoration = ring.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.color, Colors.white);
      expect((decoration.border! as Border).top.width, 4);

      await advanceTo(tester, game, roles, 'day');
      expect(find.byKey(ringKey), findsNothing);
      if (night == 1) {
        await tester.runAsync(() async {
          await game.nextNightState(roles);
        });
        await tester.pump();
      }
    }
  });

  testWidgets('other nightly roles use the same visible ring',
      (tester) async {
    final roles = [
      characterFor('poisoner'),
      characterFor('empath'),
      characterFor('dreamer'),
      characterFor('oracle'),
      characterFor('gambler'),
      characterFor('fortuneteller'),
    ];
    final game = await runningGame(tester, roles);

    await tester.pumpWidget(
      ChangeNotifierProvider<GameStateService>.value(
        value: game,
        child: MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final role in roles)
                  CharacterAvatar(
                    character: role,
                    showIsSelected: true,
                    showName: false,
                    size: 75,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final firstNight = ['poisoner', 'empath', 'dreamer', 'fortuneteller'];
    final otherNight = [
      'poisoner', 'empath', 'dreamer', 'oracle', 'gambler', 'fortuneteller',
    ];
    for (final night in [1, 2]) {
      for (final roleId in night == 1 ? firstNight : otherNight) {
        await advanceTo(
          tester, game, roles, 'role:$roleId:instance-$roleId',
        );
        final highlighted = roles.where(game.isCharacterHighlighted).toList();
        expect(highlighted.map((role) => role.roleId), [roleId]);

        // Every token shares CharacterAvatar: exactly the active role gets
        // the outline; non-active roles must remain unhighlighted.
        expect(
          find.byKey(const ValueKey('character-avatar-highlight-outline')),
          findsOneWidget,
        );
      }
      await advanceTo(tester, game, roles, 'day');
      if (night == 1) {
        await tester.runAsync(() async {
          await game.nextNightState(roles);
        });
        await tester.pump();
      }
    }
  });

  testWidgets('selection-color and bluff outlines remain supported',
      (tester) async {
    final role = characterFor('fortuneteller');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterAvatar(
          character: role,
          showIsSelected: true,
          forSelectCharacter: true,
          isSelected: true,
          showName: false,
          selectionBorderColor: Colors.amber,
          size: 95,
        ),
      ),
    ));
    final ring = tester.widget<Container>(
      find.byKey(const ValueKey('character-avatar-highlight-outline')),
    );
    final decoration = ring.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.color, Colors.amber);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterAvatar(
          character: role,
          showIsSelected: true,
          forSelectCharacter: true,
          isBluff: true,
          showName: false,
          size: 95,
        ),
      ),
    ));
    final redRing = tester.widget<Container>(
      find.byKey(const ValueKey('character-avatar-highlight-outline')),
    );
    final redDecoration = redRing.decoration! as BoxDecoration;
    expect((redDecoration.border! as Border).top.color, Colors.redAccent);
  });
}
