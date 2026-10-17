import 'package:blood_on_the_clocktower/my_app.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Grimoire theme uses the local display and body fonts', () {
    final theme = GrimoireTheme.build();
    expect(theme.textTheme.headlineSmall?.fontFamily, 'Cinzel');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'SourceSans3');
    expect(theme.colorScheme.primary, GrimoireColors.antiqueGold);
    expect(theme.scaffoldBackgroundColor, GrimoireColors.background);
  });

  testWidgets('home screen fits narrow German and English phone viewports',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final configuration in [
      (locale: const Locale('de'), width: 360.0),
      (locale: const Locale('en'), width: 430.0),
    ]) {
      tester.view.physicalSize = Size(configuration.width, 800);
      SharedPreferences.setMockInitialValues(
        <String, Object>{'locale': configuration.locale.languageCode},
      );
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

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('homeCharacterOverviewButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('homeStatisticsButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('homeSettingsButton')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('homeStatisticsButton'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('homeSettingsButton'))).dx,
        ),
      );
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
