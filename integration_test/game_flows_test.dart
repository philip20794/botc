import 'dart:convert';

import 'package:blood_on_the_clocktower/components/savant_generator.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/my_app.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/custom_script_import_screen.dart';
import 'package:blood_on_the_clocktower/screens/playername_screen.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_screen.dart';
import 'package:blood_on_the_clocktower/screens/rules_selection_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestClock {
  DateTime value = DateTime.utc(2026, 1, 2, 20);

  DateTime call() => value;

  void advance(Duration duration) => value = value.add(duration);
}

class GameFixture {
  GameFixture._({
    required this.scripts,
    required this.nightOrder,
    required this.chronicle,
    required this.queue,
    required this.characters,
    required this.game,
    required this.language,
    required this.roleNotes,
    required this.settings,
    required this.clock,
  });

  final ScriptService scripts;
  final NightOrderService nightOrder;
  final ChronicleService chronicle;
  final GameRecordUploadQueue queue;
  final CharacterService characters;
  final GameStateService game;
  final LanguageService language;
  final RoleNotesService roleNotes;
  final SettingsService settings;
  final TestClock clock;

  static Future<GameFixture> create({bool clearStorage = true}) async {
    if (clearStorage) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    }
    final scripts = ScriptService();
    final nightOrder = NightOrderService();
    final chronicle = ChronicleService();
    final queue = GameRecordUploadQueue();
    final characters = CharacterService(chronicleService: chronicle);
    final language = LanguageService();
    final roleNotes = RoleNotesService();
    final settings = SettingsService();
    final clock = TestClock();
    final game = GameStateService(
      scriptService: scripts,
      nightOrderService: nightOrder,
      chronicleService: chronicle,
      gameRecordUploadQueue: queue,
      now: clock.call,
    );
    await Future.wait([
      scripts.ready,
      nightOrder.ready,
      chronicle.ready,
      queue.ready,
      characters.init(),
      language.initialized,
      roleNotes.init(),
      settings.initialized,
      game.ready,
    ]);
    await characters.loadAllCharactersFromJson(const Locale('en'));
    return GameFixture._(
      scripts: scripts,
      nightOrder: nightOrder,
      chronicle: chronicle,
      queue: queue,
      characters: characters,
      game: game,
      language: language,
      roleNotes: roleNotes,
      settings: settings,
      clock: clock,
    );
  }

  Widget app() => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: chronicle),
          ChangeNotifierProvider.value(value: characters),
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: nightOrder),
          ChangeNotifierProvider.value(value: queue),
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider.value(value: roleNotes),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MyApp(),
      );

  Widget screen(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: chronicle),
          ChangeNotifierProvider.value(value: characters),
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider.value(value: nightOrder),
          ChangeNotifierProvider.value(value: queue),
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider.value(value: roleNotes),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          locale: language.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  List<Character> configureSixPlayerGame() {
    const ids = [
      'washerwoman',
      'librarian',
      'chef',
      'empath',
      'poisoner',
      'imp'
    ];
    for (final id in ids) {
      characters.addCharacter(
        characters.allCharacters.firstWhere((role) => role.roleId == id),
      );
    }
    characters.syncPlayerNames(game.playerNames);
    return characters.gameCharactersWithoutDrunkAndFabled;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TEST 1 - creates and starts a new game', (tester) async {
    final fixture = await GameFixture.create();
    await tester.pumpWidget(fixture.app());
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Players').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlayernameScreen), findsOneWidget);
    for (final name in ['Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Finn']) {
      await tester.enterText(find.byType(TextField), name);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    await tester.drag(
        find.byIcon(Icons.drag_handle).first, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(fixture.game.playerNames.first, 'Bob');

    final roles = fixture.configureSixPlayerGame();
    for (final bluff in ['monk', 'soldier', 'ravenkeeper']) {
      await fixture.game.toggleDemonBluff(
        bluff,
        isEligible: true,
        isGameCharacter: false,
      );
    }
    expect(fixture.game.demonBluffRoleIds, hasLength(3));
    await fixture.game.setShowCharactersToPlayers(true);
    await fixture.game.startNewGame(
      roles,
      completeSetupCharacters: fixture.characters.gameCharacters,
      scriptCatalog: fixture.characters.allCharacters,
    );
    expect(fixture.game.nightCount, 1);
    expect(fixture.game.activeGameRecordCapture?.players, hasLength(6));
  });

  testWidgets('TEST 2 - advances night, day, reminders and life state',
      (tester) async {
    final fixture = await GameFixture.create();
    for (final name in ['Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Finn']) {
      await fixture.game.addPlayerName(name);
    }
    final roles = fixture.configureSixPlayerGame();
    await fixture.game
        .startNewGame(roles, scriptCatalog: fixture.characters.allCharacters);
    await tester.pumpWidget(fixture.app());
    await tester.pump(const Duration(milliseconds: 1200));

    final reminder = roles.first.tokens.first;
    await fixture.game.addTokenToCharacter(roles, roles[1], reminder);
    expect(fixture.game.tokensOfCharacter(roles[1]), contains(reminder));
    final quickFlows = fixture.game.quickFlowEntries(roles);
    if (quickFlows.isNotEmpty) {
      await fixture.game.activateQuickFlowEntry(quickFlows.first, roles);
      await fixture.game.skipQuickFlowInfo(quickFlows.first);
    }
    await fixture.chronicle.recordNightVisit(roles.first, 1);
    fixture.clock.advance(const Duration(minutes: 10));
    await fixture.game.startDay(roles);
    expect(fixture.game.isDay(), isTrue);
    await fixture.game.toggleCharacterAlive(roles.first);
    expect(fixture.game.isCharacterAlive(roles.first), isFalse);
    fixture.clock.advance(const Duration(minutes: 20));
    await fixture.game.nextNight(roles);
    expect(fixture.game.nightCount, 2);
    expect(fixture.game.tokensOfCharacter(roles[1]), contains(reminder));
    expect(fixture.chronicle.activeChronicle?.events, isNotEmpty);
  });

  testWidgets('TEST 3 - completes, queues once, and permits a new game',
      (tester) async {
    final fixture = await GameFixture.create();
    for (final name in ['Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Finn']) {
      await fixture.game.addPlayerName(name);
    }
    final roles = fixture.configureSixPlayerGame();
    await fixture.game
        .startNewGame(roles, scriptCatalog: fixture.characters.allCharacters);
    fixture.clock.advance(const Duration(minutes: 10));
    await fixture.game.startDay(roles);
    fixture.clock.advance(const Duration(minutes: 20));
    await fixture.game.endGame(
      winningTeam: 'good',
      gameCharacters: roles,
      characterService: fixture.characters,
    );
    expect(fixture.game.lastCompletedGameRecord, isNotNull);
    expect(fixture.chronicle.lastChronicle?.winningTeam, 'good');
    expect(fixture.queue.records, hasLength(1));
    final completedId = fixture.queue.records.single.gameId;
    expect(await fixture.queue.enqueue(fixture.queue.records.single), isFalse);
    expect(fixture.queue.records.single.gameId, completedId);

    await fixture.game
        .startNewGame(roles, scriptCatalog: fixture.characters.allCharacters);
    expect(fixture.game.nightCount, 1);
  });

  testWidgets('TEST 4 - restores state and cancellation leaves it unchanged',
      (tester) async {
    final fixture = await GameFixture.create();
    for (final name in ['Alice', 'Bob', 'Cara', 'Dan', 'Eve', 'Finn']) {
      await fixture.game.addPlayerName(name);
    }
    final roles = fixture.configureSixPlayerGame();
    await fixture.game
        .startNewGame(roles, scriptCatalog: fixture.characters.allCharacters);
    final token = roles.first.tokens.first;
    await fixture.game.addTokenToCharacter(roles, roles[1], token);
    final eventCount = fixture.chronicle.activeChronicle!.events.length;

    final restored = await GameFixture.create(clearStorage: false);
    final restoredRoles =
        restored.characters.gameCharactersWithoutDrunkAndFabled;
    expect(restored.game.playerNames, fixture.game.playerNames);
    expect(restoredRoles.map((role) => role.roleId),
        roles.map((role) => role.roleId));
    expect(restored.game.nightCount, 1);
    expect(restored.game.tokensOfCharacter(restoredRoles[1]), isNotEmpty);
    expect(restored.chronicle.activeChronicle!.events.length, eventCount);

    await tester.pumpWidget(restored.app());
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.apps));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    if (find.text('Cancel').evaluate().isNotEmpty) {
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    expect(restored.game.nightCount, 1);
    expect(restored.game.tokensOfCharacter(restoredRoles[1]), isNotEmpty);
    expect(restored.chronicle.activeChronicle!.events.length, eventCount);
  });

  testWidgets('TEST 5 - imports, uses, protects, and deletes custom scripts',
      (tester) async {
    final fixture = await GameFixture.create();
    await tester.pumpWidget(fixture.screen(const CustomScriptImportScreen()));
    await tester.pumpAndSettle();

    String scriptJson(String name, {bool unknownRole = false}) => jsonEncode([
          {'id': '_meta', 'name': name},
          'imp',
          if (unknownRole) 'e2e_unknown_role',
        ]);

    final input = find.byKey(const ValueKey('scriptImportPasteJson'));
    await tester.enterText(input, scriptJson('Cancelled script'));
    await tester.tap(find.byKey(const ValueKey('scriptImportAnalyzeText')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scriptImportPreview')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fixture.scripts.customScripts, isEmpty,
        reason: 'Closing a preview must not persist a draft.');

    await tester.enterText(input, scriptJson('E2E custom script', unknownRole: true));
    await tester.tap(find.byKey(const ValueKey('scriptImportAnalyzeText')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scriptImportMap-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'monk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('monk').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scriptImportConfirm')));
    await tester.pumpAndSettle();

    expect(fixture.scripts.customScripts, hasLength(1));
    final imported = fixture.scripts.customScripts.single;
    expect(imported.roleIds, ['imp', 'monk']);
    expect(
      await fixture.scripts.selectScript(imported.id, gameIsRunning: false),
      isTrue,
    );

    await fixture.game.addPlayerName('Alice');
    await fixture.game.addPlayerName('Bob');
    fixture.characters.clearGameCards();
    for (final id in imported.roleIds) {
      fixture.characters.addCharacter(
        fixture.characters.allCharacters.firstWhere((role) => role.roleId == id),
      );
    }
    final roles = fixture.characters.gameCharactersWithoutDrunkAndFabled;
    await fixture.game.startNewGame(
      roles,
      scriptCatalog: fixture.characters.allCharacters,
    );
    expect(
      await fixture.scripts.selectScript(
        ScriptService.troubleBrewingId,
        gameIsRunning: true,
      ),
      isFalse,
    );
    expect(fixture.scripts.selectedScriptId, imported.id);

    fixture.clock.advance(const Duration(minutes: 1));
    await fixture.game.endGame(
      winningTeam: 'good',
      gameCharacters: roles,
      characterService: fixture.characters,
    );
    expect(
      await fixture.scripts.removeScript(imported.id, gameIsRunning: false),
      isTrue,
    );
    expect(fixture.scripts.customScripts, isEmpty);
  });

  testWidgets('TEST 6 - manages, restores, resets, and clears role notes',
      (tester) async {
    final fixture = await GameFixture.create();
    await fixture.game.addPlayerName('Alice');
    await fixture.game.addPlayerName('Bob');
    await tester.pumpWidget(fixture.screen(const RoleNotesScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(RoleNotesScreen), findsOneWidget);

    const board = Size(400, 400);
    await fixture.roleNotes.setPlayerPosition(
      'Alice',
      const Offset(320, 50),
      board,
      80,
    );
    final roleImages = fixture.characters.allCharacters
        .where((role) => ['imp', 'monk', 'chef', 'empath', 'soldier']
            .contains(role.roleId))
        .map((role) => role.image)
        .toList();
    await fixture.roleNotes.setRolesForPlayer('Alice', roleImages);
    expect(fixture.roleNotes.roleImagesFor('Alice'), hasLength(4));
    await fixture.roleNotes.removeRoleFromPlayer('Alice', roleImages.first);
    expect(fixture.roleNotes.roleImagesFor('Alice'), hasLength(3));

    final restored = await GameFixture.create(clearStorage: false);
    expect(restored.roleNotes.positionOf('Alice'), isNotNull);
    expect(restored.roleNotes.roleImagesFor('Alice'), hasLength(3));
    await restored.roleNotes.resetPositions(['Alice', 'Bob'], board, 80);
    expect(restored.roleNotes.positionOf('Alice'), isNot(const Offset(320, 50)));
    await restored.roleNotes.clearAllRoleNotes();
    expect(restored.roleNotes.hasAnyRoleNotes(), isFalse);
  });

  testWidgets('TEST 7 - persists settings and uses settings navigation helpers',
      (tester) async {
    final fixture = await GameFixture.create();
    await tester.pumpWidget(fixture.screen(const AppSettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();
    expect(fixture.language.locale, const Locale('de'));

    await fixture.settings.setCharacterKnobSize(112);
    await fixture.settings.setTokenOffsetX(52);
    final restored = await GameFixture.create(clearStorage: false);
    expect(restored.language.locale, const Locale('de'));
    expect(restored.settings.characterKnobSize, 112);
    expect(restored.settings.tokenOffsetX, 52);

    await tester.tap(find.text('Regeln').last);
    await tester.pumpAndSettle();
    expect(find.byType(RulesSelectionScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AppSettingsScreen), findsOneWidget);

    await restored.game.addPlayerName('Alice');
    await restored.game.addPlayerName('Bob');
    restored.characters.clearGameCards();
    for (final id in ['savant', 'imp', 'witch']) {
      restored.characters.addCharacter(
        restored.characters.allCharacters.firstWhere((role) => role.roleId == id),
      );
    }
    await tester.pumpWidget(restored.screen(const SavantGenerator()));
    await tester.pumpAndSettle();
    expect(find.text('No Savant statement available.'), findsNothing);
    await tester.tap(find.byType(SavantGenerator));
    await tester.pump();
    expect(find.textContaining('['), findsNothing);
  });
}
