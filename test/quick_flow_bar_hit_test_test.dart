import 'package:blood_on_the_clocktower/components/quick_flow_bar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character _quickFlowOwner() => Character.fromJson({
      'id': 'owner',
      'roleId': 'owner',
      'name': 'Owner',
      'descriptionShort': '',
      'descriptionLong': '',
      'howToRun': '',
      'image': 'Icon_owner',
      'fraction': 'townsfolk',
      'gameset': ['experimental'],
      'tokens': [],
      'wakeUpEveryNight': false,
      'wakeUpAtFirstNight': false,
      'nightStateNumbersFirstNight': <double>[],
      'nightStateNumbersOtherNights': <double>[],
      'tipsAndTricks': <String>[],
      'bluffs': <String>[],
      'quickFlow': {
        'setup': [
          {
            'id': 'info',
            'type': 'showInfo',
            'recipient': {'type': 'manual'},
            'presentation': {'kind': 'unknown'},
          },
        ],
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a character drag passes through empty QuickFlow bar viewport space',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final gameState = GameStateService();
    await gameState.ready;
    final owner = _quickFlowOwner();
    var emptySpaceDragEnded = false;
    var overlappingDragEnded = false;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsService(),
        child: MaterialApp(
          home: Scaffold(
            body: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  // This is the same paint order as the Playground: the bar is
                  // below character tokens, so an overlapping token wins.
                  Align(
                    alignment: Alignment.center,
                    child: QuickFlowBar(
                      gameCharacters: [owner],
                      allCharacters: [owner],
                      gameState: gameState,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: constraints.maxHeight / 2 - 25,
                    child: _draggableToken(
                      key: const ValueKey('draggable-character-token-empty'),
                      onDragEnd: () => emptySpaceDragEnded = true,
                    ),
                  ),
                  Positioned(
                    left: constraints.maxWidth / 2 - 25,
                    top: constraints.maxHeight / 2 - 25,
                    child: _draggableToken(
                      key: const ValueKey('draggable-character-token-overlap'),
                      onDragEnd: () => overlappingDragEnded = true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick-flow-bar')), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('quick-flow-scroll-view')))
          .hitTestBehavior,
      HitTestBehavior.deferToChild,
    );

    await tester.drag(
      find.byKey(const ValueKey('draggable-character-token-empty')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(emptySpaceDragEnded, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('draggable-character-token-overlap')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(overlappingDragEnded, isTrue);
  });
}

Widget _draggableToken({required Key key, required VoidCallback onDragEnd}) =>
    Draggable<String>(
      data: 'character',
      feedback: const SizedBox(width: 50, height: 50),
      onDragEnd: (_) => onDragEnd(),
      child: Container(
        key: key,
        width: 50,
        height: 50,
        color: Colors.red,
      ),
    );
