import 'package:blood_on_the_clocktower/my_app.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app starts on the home screen', (WidgetTester tester) async {
    final scriptService = ScriptService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => LanguageService()),
          ChangeNotifierProvider(create: (context) => CharacterService()),
          ChangeNotifierProvider.value(value: scriptService),
          ChangeNotifierProvider(
            create: (context) => GameStateService(
              scriptService: scriptService,
            ),
          ),
          ChangeNotifierProvider(create: (context) => RoleNotesService()),
          ChangeNotifierProvider(create: (context) => SettingsService()),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isTrue,
    );
  });
}
