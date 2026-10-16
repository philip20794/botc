import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<GameStateService> pumpPlayerScreen(WidgetTester tester) async {
    await pumpPlayerScreen(tester);
    return game;
  }

  testWidgets('player name field matches the full width of its panel',
      (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Service initialization uses asynchronous preferences and assets;
    // initialize outside the widget test's fake-async clock.
    late GameStateService game;
    await tester.runAsync(() async {
      final scripts = ScriptService();
      final order = NightOrderService();
      await Future.wait([scripts.ready, order.ready]);
      game = GameStateService(
        scriptService: scripts,
        nightOrderService: order,
      );
      await game.ready;
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<GameStateService>.value(
        value: game,
        child: MaterialApp(
          theme: GrimoireTheme.build(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlayernameScreen(),
        ),
      ),
    );
    await tester.pump();

    final input = find.byKey(const ValueKey('player-name-input'));
    final panel = find.ancestor(
      of: input,
      matching: find.byType(GrimoirePanel),
    );
    expect(input, findsOneWidget);
    expect(panel, findsOneWidget);
    expect(
      tester.getSize(input).width,
      closeTo(tester.getSize(panel).width, 0.1),
      reason: 'No additional inset should shrink the player name input',
    );
  });

  testWidgets('keyboard Done adds successive players without losing focus',
      (tester) async {
    final game = await pumpPlayerScreen(tester);
    final inputFinder = find.byKey(const ValueKey('player-name-input'));
    final field = tester.widget<TextField>(inputFinder);
    expect(field.textInputAction, TextInputAction.done);

    await tester.enterText(inputFinder, 'Max');
    await tester.pump();
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // Simulate the actual Android keyboard checkmark/Done action.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(game.playerNames, ['Max']);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // The keyboard must stay active, so the next name can be entered
    // immediately without tapping the field again.
    await tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'Lisa'),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(game.playerNames, ['Max', 'Lisa']);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('plus button keeps the same repeated-add behavior',
      (tester) async {
    final game = await pumpPlayerScreen(tester);
    final inputFinder = find.byKey(const ValueKey('player-name-input'));
    final field = tester.widget<TextField>(inputFinder);

    await tester.enterText(inputFinder, 'Tom');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('add-player-button')));
    await tester.pump();
    expect(game.playerNames, ['Tom']);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });
}
