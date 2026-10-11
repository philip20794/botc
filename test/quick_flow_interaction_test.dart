import 'package:blood_on_the_clocktower/components/player_interaction_target.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/screens/quick_flow_selected_character_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Character testCharacter() => Character.fromJson({
        'id': 'farmer-instance',
        'roleId': 'farmer',
        'name': 'Farmer',
        'descriptionShort': '',
        'descriptionLong': '',
        'howToRun': '',
        'image': 'Icon_farmer',
        'fraction': 'townsfolk',
        'gameset': ['experimental'],
        'tokens': [],
        'wakeUpEveryNight': false,
        'wakeUpAtFirstNight': false,
        'nightStateNumbersFirstNight': [],
        'nightStateNumbersOtherNights': [],
        'tipsAndTricks': [],
        'bluffs': [],
      });

  MaterialApp safeApp(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  testWidgets('safe character screen returns to selection on system back',
      (tester) async {
    var result = true;
    await tester.pumpWidget(safeApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => QuickFlowSelectedCharacterScreen(
                        character: testCharacter(),
                      ),
                    ),
                  ) ??
                  true;
            },
            child: const Text('select'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-flow-character-continue')),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.text('select'), findsOneWidget);
  });

  testWidgets('safe character screen requires storyteller confirmation',
      (tester) async {
    var result = false;
    await tester.pumpWidget(safeApp(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => QuickFlowSelectedCharacterScreen(
                        character: testCharacter(),
                      ),
                    ),
                  ) ??
                  false;
            },
            child: const Text('select'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('select'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('quick-flow-character-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Only the storyteller may continue.'), findsOneWidget);
    await tester.tap(find.text('I am the storyteller'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('tap and long press with an active reminder stay exclusive',
      (tester) async {
    var quickAssignments = 0;
    var menuOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerInteractionTarget(
            key: const ValueKey('player'),
            quickReminderActive: true,
            onQuickTap: () => quickAssignments++,
            onOpenMenu: () => menuOpens++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player')));
    await tester.pump();
    expect(quickAssignments, 1);
    expect(menuOpens, 0);

    await tester.longPress(find.byKey(const ValueKey('player')));
    await tester.pump();
    expect(quickAssignments, 1,
        reason: 'A long press must not also dispatch the quick tap.');
    expect(menuOpens, 1);
  });

  testWidgets('tap and long press without a reminder both open the menu',
      (tester) async {
    var quickAssignments = 0;
    var menuOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerInteractionTarget(
            key: const ValueKey('player'),
            quickReminderActive: false,
            onQuickTap: () => quickAssignments++,
            onOpenMenu: () => menuOpens++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player')));
    await tester.pump();
    await tester.longPress(find.byKey(const ValueKey('player')));
    await tester.pump();
    expect(quickAssignments, 0);
    expect(menuOpens, 2);
  });
}
