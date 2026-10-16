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

  testWidgets('player name field matches the full width of its panel',
      (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scripts = ScriptService();
    final order = NightOrderService();
    await Future.wait([scripts.ready, order.ready]);
    final game = GameStateService(
      scriptService: scripts,
      nightOrderService: order,
    );
    await game.ready;

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
    await tester.pumpAndSettle();

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
}
