import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/statistics_data.dart';
import 'package:blood_on_the_clocktower/screens/statistics_screen.dart';
import 'package:blood_on_the_clocktower/services/statistics_repository.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStatisticsRepository implements StatisticsRepository {
  int globalLoads = 0;
  int roleLoads = 0;
  int scriptLoads = 0;
  bool fail = false;
  bool empty = false;

  @override
  Future<StatisticsTotals?> loadOverview() async {
    globalLoads++;
    if (fail) throw StateError('offline');
    if (empty) return null;
    return StatisticsTotals.fromMap({
      'games': 120, 'demoGames': 120, 'goodWins': 62,
      'evilWins': 58, 'totalDurationMs': 720000000,
      'totalPlayers': 1140, 'totalDays': 360, 'totalNights': 470,
      'totalDayDurationMs': 350000000,
      'totalNightDurationMs': 370000000,
      'deaths': 550, 'revivals': 28,
    });
  }

  @override
  Future<List<StatisticsRole>> loadRoles() async {
    roleLoads++;
    if (fail) throw StateError('offline');
    if (empty) return [];
    return [
      StatisticsRole.fromMap('imp', {
        'appearances': 40, 'wins': 20, 'losses': 20,
        'totalDurationMs': 120000000, 'demoAppearances': 40,
        'roleChanges': 2,
      }),
      StatisticsRole.fromMap('monk', {
        'appearances': 15, 'wins': 8, 'losses': 7,
        'totalDurationMs': 45000000, 'demoAppearances': 15,
        'roleChanges': 0,
      }),
    ];
  }

  @override
  Future<List<StatisticsScript>> loadScripts() async {
    scriptLoads++;
    if (fail) throw StateError('offline');
    if (empty) return [];
    return [
      StatisticsScript.fromMap('a' * 64, {
        'scriptId': 'standard:trouble_brewing',
        'name': 'Trouble Brewing', 'isCustom': false, 'roleCount': 28,
        'games': 120, 'demoGames': 120, 'goodWins': 62, 'evilWins': 58,
        'totalDurationMs': 720000000, 'totalPlayers': 1140,
      }),
    ];
  }
}

Widget testDashboard(FakeStatisticsRepository data, Locale locale) =>
    MaterialApp(
      locale: locale,
      theme: GrimoireTheme.build(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StatisticsScreen(repository: data),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('statistics parsers tolerate missing counters and calculate averages', () {
    final total = StatisticsTotals.fromMap({
      'games': 4, 'goodWins': 3, 'totalDurationMs': 24000000,
      'totalPlayers': 32, 'totalDays': 8, 'totalNights': 12,
    });
    expect(total.averageDurationMinutes, 100);
    expect(total.averagePlayers, 8);
    expect(total.goodWinRate, 75);
    expect(total.averageDays, 2);
    expect(total.averageNights, 3);
    final empty = StatisticsTotals.fromMap({'games': 0});
    expect(empty.averageDurationMinutes, 0);
    expect(empty.goodWinRate, 0);
    final role = StatisticsRole.fromMap('imp',
      {'appearances': 4, 'wins': 3, 'totalDurationMs': 24000000});
    expect(role.winRate, 75);
    expect(role.averageMinutes, 100);
  });

  testWidgets('mobile overview shows real precomputed numbers and demo banner',
      (tester) async {
    final data = FakeStatisticsRepository();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 780);

    await tester.pumpWidget(testDashboard(data, const Locale('de')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statisticsContent')), findsOneWidget);
    expect(find.text('Globale Statistik'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.textContaining('Testspiele'), findsWidgets);
    expect(data.globalLoads, 1);
    expect(data.roleLoads, 0);
    expect(data.scriptLoads, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('stats-refresh')));
    await tester.pumpAndSettle();
    expect(data.globalLoads, 2);
  });

  testWidgets('loads each tab lazily and supports role search and details',
      (tester) async {
    final data = FakeStatisticsRepository();
    await tester.pumpWidget(testDashboard(data, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stats-tab-1')));
    await tester.pumpAndSettle();
    expect(data.roleLoads, 1);
    expect(find.text('Character rankings'), findsOneWidget);
    expect(find.text('Imp'), findsOneWidget);
    expect(find.text('Monk'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('stats-role-search')), 'imp');
    await tester.pumpAndSettle();
    expect(find.text('Imp'), findsOneWidget);
    expect(find.text('Monk'), findsNothing);
    await tester.tap(find.text('Imp'));
    await tester.pumpAndSettle();
    expect(find.text('Role changes'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('stats-tab-2')));
    await tester.tap(find.byKey(const ValueKey('stats-tab-2')));
    await tester.pumpAndSettle();
    expect(data.scriptLoads, 1);
    expect(find.text('Trouble Brewing'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('stats-tab-3')));
    await tester.tap(find.byKey(const ValueKey('stats-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Game flow'), findsWidgets);
    expect(data.globalLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty and recoverable network error states',
      (tester) async {
    final data = FakeStatisticsRepository()..empty = true;
    await tester.pumpWidget(testDashboard(data, const Locale('de')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noch keine Statistikdaten'), findsOneWidget);

    data.fail = true;
    await tester.tap(find.byKey(const ValueKey('stats-refresh')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Statistiken konnten nicht'), findsOneWidget);

    data.fail = false;
    data.empty = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Globale Statistik'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
