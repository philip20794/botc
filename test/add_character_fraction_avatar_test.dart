import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/add_character_while_playing.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows every fraction icon without catalog characters',
      (tester) async {
    final scriptService = ScriptService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CharacterService()),
          ChangeNotifierProvider.value(value: scriptService),
          ChangeNotifierProvider(
            create: (_) => GameStateService(scriptService: scriptService),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('de')],
          home: AddCharacterWhilePlaying(),
        ),
      ),
    );

    const assetPaths = {
      'townsfolk': 'assets/images/characters/Townsfolk.png',
      'outsider': 'assets/images/characters/Outsider.png',
      'minion': 'assets/images/characters/Minion.png',
      'demon': 'assets/images/characters/Demon.png',
      'traveller': 'assets/images/characters/Traveller.png',
      'fabled': 'assets/images/characters/Fabled.png',
      'loric': 'assets/images/characters/Loric.png',
    };

    for (final entry in assetPaths.entries) {
      final avatar = find.byKey(ValueKey('fractionAvatar-${entry.key}'));
      expect(avatar, findsOneWidget);

      final image = tester.widget<Image>(
        find.descendant(of: avatar, matching: find.byType(Image)),
      );
      expect((image.image as AssetImage).assetName, entry.value);
    }
  });
}
