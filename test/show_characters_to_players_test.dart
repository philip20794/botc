import 'dart:convert';

import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/show_characters_to_players.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
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
    ) as List<dynamic>).map((item) =>
        Map<String, dynamic>.from(item as Map)).toList(growable: false);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Character role(String roleId, String playerName) {
    final raw = catalog.singleWhere((item) => item['roleId'] == roleId);
    return Character.fromJson({
      ...raw,
      'id': '$roleId-$playerName',
      'playerName': playerName,
    });
  }

  Future<void> showFlow(WidgetTester tester, {required int players}) async {
    late CharacterService characters;
    late GameStateService game;
    await tester.runAsync(() async {
      final chronicle = ChronicleService();
      final script = ScriptService();
      final nightOrder = NightOrderService();
      await Future.wait([chronicle.ready, script.ready, nightOrder.ready]);
      game = GameStateService(
        chronicleService: chronicle,
        scriptService: script,
        nightOrderService: nightOrder,
      );
      await game.ready;
      characters = CharacterService(chronicleService: chronicle);
      await characters.init();
      characters.addCharacter(role('chef', 'Alice'));
      if (players > 1) characters.addCharacter(role('empath', 'Bob'));
      await characters.flushPendingGameWrites();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<CharacterService>.value(value: characters),
        ChangeNotifierProvider<GameStateService>.value(value: game),
      ],
      child: MaterialApp(
        theme: GrimoireTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ShowCharactersToPlayers(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  ElevatedButton continueButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('role-reveal-continue')),
      );

  int chargePercent(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('role-reveal-progress-percent')),
    ).data!;
    return int.parse(text.replaceAll('%', ''));
  }

  testWidgets('short press does not reveal or unlock next player',
      (tester) async {
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    expect(continueButton(tester).onPressed, isNull);
    expect(chargePercent(tester), 0);
    // A plain tap must never expose secret character data.
    await tester.tap(find.byKey(const ValueKey('role-reveal-eye')));
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    await tester.pump(); // Establish first animation frame on touch-down.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CharacterAvatar), findsNothing);
    final partialFill = tester.getSize(
      find.byKey(const ValueKey('role-reveal-progress-fill')),
    ).width;
    final fullWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    ).width;
    expect(partialFill, greaterThan(0),
        reason: 'The button must start filling on first touch.');
    expect(partialFill, lessThan(fullWidth));
    expect(chargePercent(tester), inInclusiveRange(24, 42));
    await gesture.up();
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);
    expect(chargePercent(tester), 0);
    expect(tester.getSize(
        find.byKey(const ValueKey('role-reveal-progress-fill'))).width, 0);
  });

  testWidgets('holding button reveals, release hides and unlocks continue',
      (tester) async {
    await showFlow(tester, players: 2);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    // A single continuous touch controls both the visible fill and reveal.
    expect(chargePercent(tester), 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final fillWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-progress-fill')),
    ).width;
    final buttonWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    ).width;
    expect(fillWidth, greaterThan(0));
    expect(fillWidth, lessThan(buttonWidth));
    expect(chargePercent(tester), inInclusiveRange(18, 34));
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.pump(const Duration(milliseconds: 280));
    expect(chargePercent(tester), inInclusiveRange(52, 68));
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);

    // The role must appear at the SAME moment the percentage reaches 100.
    await tester.pump(const Duration(milliseconds: 350));
    expect(chargePercent(tester), 100);
    expect(find.byType(CharacterAvatar), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
    await hold.up();
    await tester.pump();
    expect(chargePercent(tester), 0);
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('role-reveal-continue')));
    await tester.pumpAndSettle();
    expect(find.text('I am Bob'), findsOneWidget);
    expect(find.byType(CharacterAvatar), findsNothing);
  });

  testWidgets('large eye also reveals and completes storyteller hand-off',
      (tester) async {
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-eye'))),
    );
    // A single continuous touch controls both the visible fill and reveal.
    expect(chargePercent(tester), 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final fillWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-progress-fill')),
    ).width;
    final buttonWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    ).width;
    expect(fillWidth, greaterThan(0));
    expect(fillWidth, lessThan(buttonWidth));
    expect(chargePercent(tester), inInclusiveRange(18, 34));
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.pump(const Duration(milliseconds: 280));
    expect(chargePercent(tester), inInclusiveRange(52, 68));
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);

    // The role must appear at the SAME moment the percentage reaches 100.
    await tester.pump(const Duration(milliseconds: 350));
    expect(chargePercent(tester), 100);
    expect(find.byType(CharacterAvatar), findsOneWidget);
    await hold.up();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('role-reveal-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('role-handoff-confirm')), findsOneWidget);
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-storyteller-start')), findsOneWidget);
  });

  testWidgets('cancelled long press resets visible fill and does not unlock',
      (tester) async {
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('role-reveal-progress-fill')),
      ).width,
      greaterThan(0),
    );
    await hold.cancel();
    await tester.pump();
    expect(chargePercent(tester), 0);
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('role-reveal-progress-fill')),
      ).width,
      0,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(CharacterAvatar), findsNothing);
  });

  for (final surface in [
    'role-reveal-eye',
    'role-reveal-hold-button',
  ]) {
    testWidgets('holding $surface survives moving outside the touch area',
        (tester) async {
      await showFlow(tester, players: 1);
      await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
      await tester.pumpAndSettle();

      final finder = find.byKey(ValueKey(surface));
      final originalBounds = tester.getRect(finder);
      final hold = await tester.startGesture(tester.getCenter(finder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(chargePercent(tester), inInclusiveRange(24, 42));

      // Drag well beyond the original widget bounds. The active touch must
      // keep its charging progress even if the scroll view wins the drag.
      await hold.moveBy(Offset(0, originalBounds.height + 110));
      await tester.pump(const Duration(milliseconds: 250));
      expect(chargePercent(tester), inInclusiveRange(55, 70));
      expect(find.byType(CharacterAvatar), findsNothing);
      expect(continueButton(tester).onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 350));
      expect(chargePercent(tester), 100);
      expect(find.byType(CharacterAvatar), findsOneWidget);

      // Movement AFTER the role is visible must not conceal it either.
      await hold.moveBy(const Offset(60, 60));
      await tester.pump();
      expect(chargePercent(tester), 100);
      expect(find.byType(CharacterAvatar), findsOneWidget);

      await hold.up();
      await tester.pump();
      expect(chargePercent(tester), 0);
      expect(find.byType(CharacterAvatar), findsNothing);
      expect(continueButton(tester).onPressed, isNotNull);
    });
  }

  testWidgets('disabled system animations cannot shorten secret hold time',
      (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(chargePercent(tester), inInclusiveRange(11, 26));
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.pump(const Duration(milliseconds: 260));
    expect(chargePercent(tester), inInclusiveRange(42, 60));
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    expect(chargePercent(tester), 100);
    expect(find.byType(CharacterAvatar), findsOneWidget);

    await hold.up();
    await tester.pump();
    expect(chargePercent(tester), 0);
    expect(find.byType(CharacterAvatar), findsNothing);
  });

  testWidgets('second finger cannot interrupt or bypass active hold',
      (tester) async {
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    );
    final primary = await tester.startGesture(center, pointer: 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final beforeSecondFinger = chargePercent(tester);
    expect(beforeSecondFinger, greaterThan(0));

    final secondary =
        await tester.startGesture(center + const Offset(10, 0), pointer: 2);
    await tester.pump(const Duration(milliseconds: 150));
    expect(chargePercent(tester), greaterThan(beforeSecondFinger));
    await secondary.up();
    await tester.pump();
    expect(chargePercent(tester), greaterThan(0));
    expect(find.byType(CharacterAvatar), findsNothing);

    await tester.pump(const Duration(milliseconds: 450));
    expect(chargePercent(tester), 100);
    expect(find.byType(CharacterAvatar), findsOneWidget);
    await primary.up();
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(chargePercent(tester), 0);
  });

  testWidgets('small phone size can scroll to the continue button',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('role-reveal-continue'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
