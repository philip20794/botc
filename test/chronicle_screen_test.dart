import 'dart:convert';

import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/chronicle_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
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
        .toList(growable: false);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Character role(String roleId, String id, String playerName) {
    final source = catalog.singleWhere((item) => item['roleId'] == roleId);
    return Character.fromJson({
      ...source,
      'id': id,
      'playerName': playerName,
    });
  }

  testWidgets(
      'Fortune Teller night entry stores and reopens two players and No',
      (tester) async {
    late ChronicleService chronicle;
    late CharacterService characters;
    late GameStateService state;
    await tester.runAsync(() async {
      chronicle = ChronicleService();
      final scripts = ScriptService();
      final order = NightOrderService();
      await Future.wait([chronicle.ready, scripts.ready, order.ready]);
      state = GameStateService(
        chronicleService: chronicle,
        scriptService: scripts,
        nightOrderService: order,
      );
      await state.ready;
      final fortuneTeller = role('fortuneteller', 'ft', 'Faye');
      final anna = role('chef', 'anna', 'Anna');
      final markus = role('empath', 'markus', 'Markus');
      final gameCharacters = [fortuneTeller, anna, markus];
      await state.startNewGame(gameCharacters);
      await state.nextNight(gameCharacters);
      for (var i = 0;
          i < 30 && state.currentNightStepId != 'role:fortuneteller:ft';
          i++) {
        await state.nextNightState(gameCharacters);
      }
      characters = CharacterService();
      await characters.init();
      await characters.loadAllCharactersFromJson(const Locale('en'));
      characters.setCharacterPositions(const {
        0: Offset(10, 200),
        1: Offset(150, 200),
        2: Offset(280, 200),
      });
    });
    expect(state.currentNightStepId, 'role:fortuneteller:ft');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chronicle),
          ChangeNotifierProvider.value(value: characters),
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChronicleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addDetails =
        find.byKey(const ValueKey('chronicle-add-fortuneReading'));
    await tester.ensureVisible(addDetails);
    await tester.pumpAndSettle();
    await tester.tap(addDetails);
    await tester.pumpAndSettle();
    final selectPlayers =
        find.byKey(const ValueKey('chronicle-select-chosenPlayers'));
    await tester.ensureVisible(selectPlayers);
    await tester.pumpAndSettle();
    await tester.tap(selectPlayers);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('chronicle-player-selection-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('player-anna')));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('chronicle-player-selection-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('player-markus')));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('chronicle-player-selection-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('chronicle-player-selection-confirm')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chronicle-answer-no')));
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(find.text('Anna + Markus → No'), findsOneWidget);
    await tester.tap(find.text('Anna + Markus → No'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Anna · Chef'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Markus · Empath'), findsOneWidget);
    final noChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('chronicle-answer-no')),
    );
    expect(noChip.selected, isTrue);

    await tester.tap(selectPlayers);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-anna')));
    await tester.tap(
      find.byKey(const ValueKey('chronicle-player-selection-back')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Anna · Chef'), findsOneWidget);
  });
}
