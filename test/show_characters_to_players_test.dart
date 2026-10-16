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

  testWidgets('short press does not reveal or unlock next player',
      (tester) async {
    await showFlow(tester, players: 1);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    expect(continueButton(tester).onPressed, isNull);
    // A plain tap must never expose secret character data.
    await tester.tap(find.byKey(const ValueKey('role-reveal-eye')));
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('role-reveal-progress-fill')),
      ).width,
      0,
      reason: 'A short press must not start charging',
    );
    await gesture.up();
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('holding button reveals, release hides and unlocks continue',
      (tester) async {
    await showFlow(tester, players: 2);
    await tester.tap(find.byKey(const ValueKey('role-handoff-confirm')));
    await tester.pumpAndSettle();

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('role-reveal-hold-button'))),
    );
    // Flutter recognizes a long press after its gesture deadline. Charging
    // starts only then, and the progress must be visually nonzero mid-hold.
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    final fillWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-progress-fill')),
    ).width;
    final buttonWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    ).width;
    expect(fillWidth, greaterThan(0));
    expect(fillWidth, lessThan(buttonWidth));
    expect(find.byType(CharacterAvatar), findsNothing);
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.byType(CharacterAvatar), findsOneWidget);
    expect(continueButton(tester).onPressed, isNull);
    await hold.up();
    await tester.pump();
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
    // Flutter recognizes a long press after its gesture deadline. Charging
    // starts only then, and the progress must be visually nonzero mid-hold.
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byType(CharacterAvatar), findsNothing);
    await tester.pump(const Duration(milliseconds: 350));
    final fillWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-progress-fill')),
    ).width;
    final buttonWidth = tester.getSize(
      find.byKey(const ValueKey('role-reveal-hold-button')),
    ).width;
    expect(fillWidth, greaterThan(0));
    expect(fillWidth, lessThan(buttonWidth));
    expect(find.byType(CharacterAvatar), findsNothing);
    await tester.pump(const Duration(milliseconds: 650));
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
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('role-reveal-progress-fill')),
      ).width,
      greaterThan(0),
    );
    await hold.cancel();
    await tester.pump();
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
