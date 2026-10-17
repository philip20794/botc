import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/screens/app_settings_screen.dart';
import 'package:blood_on_the_clocktower/screens/statistics_sync_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/firestore_game_repository.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Writer implements FirestoreGameDocumentWriter {
  final Map<String, Map<String, dynamic>> saved = {};

  @override
  Future<FirestoreGameDocumentCreateResult> createIfAbsent(
      String id, Map<String, dynamic> data) async {
    if (saved.containsKey(id)) {
      return FirestoreGameDocumentCreateResult.alreadyExists;
    }
    saved[id] = data;
    return FirestoreGameDocumentCreateResult.created;
  }
}

GameRecord _record() {
  final start = DateTime.utc(2026, 10, 17, 7);
  final end = start.add(const Duration(minutes: 30));
  const roles = ['monk'];
  return GameRecord(
    gameId: 'game_statistics_test_001',
    startedAt: start,
    endedAt: end,
    totalDuration: end.difference(start),
    playerCount: 1,
    winnerTeam: GameTeam.good,
    script: GameRecordScript(
      scriptId: 'script_statistics_test',
      name: 'Trouble Brewing',
      isCustom: false,
      roleIds: roles,
      contentHash: GameRecordScript.contentHashForRoleIds(roles),
    ),
    players: const [
      GameRecordPlayer(
        anonymizedPlayerId: 'player_statistics_001',
        position: 0,
        actualStartRoleId: 'monk',
        displayedStartRoleId: 'monk',
        startTeam: GameTeam.good,
        endRoleId: 'monk',
        endTeam: GameTeam.good,
      ),
    ],
    phases: [
      GameRecordPhase(
        phaseId: 'phase_statistics_001',
        type: GameRecordPhaseType.night,
        round: 1,
        startedAt: start,
        endedAt: end,
        duration: end.difference(start),
      ),
    ],
    chronicleEvents: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings opens upload dashboard without an always-on widget',
      (tester) async {
    final queue = GameRecordUploadQueue();
    await queue.ready;
    final repository = FirestoreGameRepository(writer: _Writer());
    final language = LanguageService();
    await language.initialized;
    final characters = CharacterService();
    await characters.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: characters),
          ChangeNotifierProvider.value(value: queue),
          Provider<FirestoreGameRepository>.value(value: repository),
        ],
        child: MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AppSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Statistik-Synchronisierung'), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-sync-content')), findsNothing);

    await tester.tap(find.text('Statistik-Synchronisierung'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsSyncScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-sync-content')),
        findsOneWidget);
    expect(find.text('Keine Spiele warten auf einen Upload.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey('retry-statistics-upload'))).onPressed, isNull);
  });

  testWidgets('dashboard shows queue and manual upload confirmation',
      (tester) async {
    final queue = GameRecordUploadQueue();
    final record = _record();
    expect(await queue.enqueue(record), isTrue);
    final writer = _Writer();
    final repository = FirestoreGameRepository(writer: writer);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: queue),
          Provider<FirestoreGameRepository>.value(value: repository),
        ],
        child: const MaterialApp(
          locale: Locale('de'),
          home: StatisticsSyncScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('pending-game-${record.gameId}')),
        findsOneWidget);
    expect(find.text('Wartet auf Upload'), findsOneWidget);
    expect(writer.saved, isEmpty,
        reason: 'Opening the dashboard must not itself upload anything.');

    await tester.tap(find.byKey(const ValueKey('retry-statistics-upload')));
    await tester.pumpAndSettle();
    expect(writer.saved, hasLength(1));
    expect(queue.confirmedUploadCount, 1);
    expect(queue.pendingCount, 0);
    expect(find.byKey(ValueKey('pending-game-${record.gameId}')),
        findsNothing);
    expect(find.byKey(ValueKey('confirmed-game-${record.gameId}')),
        findsOneWidget);
  });
}
