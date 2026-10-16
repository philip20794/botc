import 'package:blood_on_the_clocktower/components/playground_center_positions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Quick Flow reminders are above the next-phase arrow and menu',
      (tester) async {
    // Typical control sizes: 76px Quick Flow viewport, 66px IconButton,
    // and 60px nine-dot icon. Check the actual visible gaps.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Align(
                alignment: Alignment.center,
                child: Icon(Icons.apps,
                    key: ValueKey('center-menu'), size: 60),
              ),
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: PlaygroundCenterPositions.nextPhase,
                  child: const SizedBox(
                    key: ValueKey('next-phase'),
                    height: 66,
                    width: 66,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: PlaygroundCenterPositions.reminders,
                  child: const SizedBox(
                    key: ValueKey('reminders'),
                    height: 76,
                    width: 280,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final reminders = tester.getRect(find.byKey(const ValueKey('reminders')));
    final nextPhase = tester.getRect(find.byKey(const ValueKey('next-phase')));
    final menu = tester.getRect(find.byKey(const ValueKey('center-menu')));

    expect(reminders.bottom, lessThan(nextPhase.top));
    expect(nextPhase.bottom, lessThan(menu.top));
    expect(nextPhase.center.dy, lessThan(menu.center.dy));
    expect(
      nextPhase.center.dy - reminders.center.dy,
      84,
      reason: 'There should not be an empty reserved reminder slot '
          'between the next-phase arrow and the nine-dot menu.',
    );
  });

  test('expanded nine-dot menu keeps the next-phase arrow clear', () {
    const topMenuItemCenter = -80.0;
    const nextPhaseHeight = 66.0;
    const topMenuItemHeight = 50.0;
    final arrowCenter =
        PlaygroundCenterPositions.nextPhaseFor(menuVisible: true).dy;

    expect(
      arrowCenter + nextPhaseHeight / 2,
      lessThan(topMenuItemCenter - topMenuItemHeight / 2),
      reason: 'Opening the menu must not cover the next-phase control.',
    );
    expect(
      PlaygroundCenterPositions.nextPhaseFor(menuVisible: false),
      PlaygroundCenterPositions.nextPhase,
    );
  });
}
