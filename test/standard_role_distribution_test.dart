import 'package:blood_on_the_clocktower/components/standard_role_distribution_indicator.dart';
import 'package:blood_on_the_clocktower/models/standard_role_distribution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard table matches all legal regular-player counts', () {
    const expected = <int, List<int>>{
      5: [3, 0, 1, 1],
      6: [3, 1, 1, 1],
      7: [5, 0, 1, 1],
      8: [5, 1, 1, 1],
      9: [5, 2, 1, 1],
      10: [7, 0, 2, 1],
      11: [7, 1, 2, 1],
      12: [7, 2, 2, 1],
      13: [9, 0, 3, 1],
      14: [9, 1, 3, 1],
      15: [9, 2, 3, 1],
    };

    expect(StandardRoleDistribution.forPlayerCount(0), isNull);
    expect(StandardRoleDistribution.forPlayerCount(4), isNull);
    for (final entry in expected.entries) {
      final result = StandardRoleDistribution.forPlayerCount(entry.key)!;
      expect(
        [result.townsfolk, result.outsiders, result.minions, result.demons],
        entry.value,
        reason: 'Incorrect base distribution for ${entry.key} players',
      );
      expect(
        result.townsfolk + result.outsiders + result.minions + result.demons,
        entry.key,
      );
    }

    final withTravellers = StandardRoleDistribution.forPlayerCount(18)!;
    expect([
      withTravellers.townsfolk,
      withTravellers.outsiders,
      withTravellers.minions,
      withTravellers.demons,
    ], [9, 2, 3, 1]);
  });

  testWidgets('shows 7/2/2/1 in blue/blue/red/red and updates by player count',
      (tester) async {
    Future<void> showCount(int count) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StandardRoleDistributionIndicator(playerCount: count),
            ),
          ),
        ),
      );
    }

    await showCount(12);
    final marker = find.byKey(
      const ValueKey('role-notes-standard-distribution'),
    );
    expect(marker, findsOneWidget);
    final keys = [
      'role-notes-townsfolk-count',
      'role-notes-outsider-count',
      'role-notes-minion-count',
      'role-notes-demon-count',
    ];
    final values = [7, 2, 2, 1];
    final colors = [
      const Color(0xFF7FC5FF),
      const Color(0xFF7FC5FF),
      const Color(0xFFFF8390),
      const Color(0xFFFF8390),
    ];
    for (var index = 0; index < keys.length; index++) {
      final widget = tester.widget<Text>(
        find.byKey(ValueKey(keys[index])),
      );
      expect(widget.data, '${values[index]}');
      expect(widget.style?.color, colors[index]);
    }

    await showCount(9);
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-townsfolk-count'))).data, '5');
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-outsider-count'))).data, '2');
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('role-notes-minion-count'))).data, '1');
    await showCount(4);
    expect(marker, findsNothing);
  });

  testWidgets('indicator does not block taps on the board beneath it',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
              const Positioned.fill(
                child: Center(
                  child: StandardRoleDistributionIndicator(playerCount: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('role-notes-standard-distribution')),
      ),
    );
    await tester.pump();
    expect(taps, 1);
  });
}
