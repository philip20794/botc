import 'package:blood_on_the_clocktower/components/app_page_route.dart';
import 'package:blood_on_the_clocktower/my_app.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/character_auswahl_screen.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('web pop disables route fade/slide and route snapshotting', () {
    final web = AppPageRoute<void>(
      builder: (_) => const SizedBox(),
      webNavigation: true,
    );
    final android = AppPageRoute<void>(
      builder: (_) => const SizedBox(),
      webNavigation: false,
    );
    expect(web.reverseTransitionDuration, Duration.zero);
    expect(web.allowSnapshotting, isFalse);
    expect(android.allowSnapshotting, isTrue);
  });

  testWidgets('web Back removes the departing route at once', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                AppPageRoute<void>(
                  webNavigation: true,
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Settings')),
                    body: const Text('Settings content'),
                  ),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Settings content'), findsOneWidget);

    // Simulate the Back button received from a browser swipe/system back.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings content'), findsNothing);
  });

  testWidgets('Home uses the same managed route for settings and characters',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final language = LanguageService();
    await language.initialized;
    final scripts = ScriptService();
    final game = GameStateService(scriptService: scripts);
    await game.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider(create: (_) => CharacterService()),
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider(create: (_) => RoleNotesService()),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    // Both the in-app AppBar back arrow and the browser/system Back event
    // should pop a single route without accumulating another Home route.
    await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(AppSettingsScreen))),
      isA<AppPageRoute>(),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppSettingsScreen), findsNothing);

    // Characters can be opened after Settings without stale routes in the
    // navigator stack. Back gestures must return directly to Home.
    final characterSelection = find.byIcon(Icons.dashboard_outlined);
    await tester.ensureVisible(characterSelection);
    await tester.tap(characterSelection);
    await tester.pumpAndSettle();
    expect(find.byType(CharacterAuswahlScreen), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(CharacterAuswahlScreen))),
      isA<AppPageRoute>(),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CharacterAuswahlScreen), findsNothing);
  });
}
