import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/utils/character_layout_positions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('Role Notes uses the configured player positions and keeps role notes',
      () async {
    const viewport = Size(360, 708);
    const board = Size(360, 652);
    final settings = SettingsService(initialViewport: viewport);
    await settings.initialized;
    final notes = RoleNotesService();
    await notes.init();
    final players = List.generate(11, (index) => 'Player ${index + 1}');
    await notes.setRolesForPlayer(players.first, ['poisoned']);

    expect(notes.needsPositionSync(
        players, board, settings.characterKnobSize, layoutSettings: settings),
        isTrue);
    await notes.ensureDefaultPositions(
      players, board, settings.characterKnobSize,
      layoutSettings: settings,
    );
    final positions = CharacterLayoutPositions.calculate(
      count: players.length,
      boardSize: board,
      characterSize: settings.characterKnobSize,
      radiusX: settings.radiusX,
      radiusY: settings.radiusY,
      startAngleDiv: settings.startAngleDiv,
      offsetX: settings.offsetX,
      offsetY: settings.offsetY,
    );
    for (var i = 0; i < players.length; i++) {
      expect(
        notes.positionOf(players[i]),
        notes.clampPlayerPosition(
          positions[i]!, board, settings.characterKnobSize,
        ),
      );
    }
    expect(notes.roleImagesFor(players.first), ['poisoned']);
    expect(notes.needsPositionSync(
      players, board, settings.characterKnobSize, layoutSettings: settings,
    ), isFalse);

    final stored = RoleNotesService();
    await stored.init();
    expect(stored.positionOf(players.first), notes.positionOf(players.first));
    expect(stored.needsPositionSync(
      players, board, settings.characterKnobSize, layoutSettings: settings,
    ), isFalse);
  });

  test('manual dragging persists until the shared layout changes', () async {
    const viewport = Size(360, 708);
    const board = Size(360, 652);
    final settings = SettingsService(initialViewport: viewport);
    await settings.initialized;
    final notes = RoleNotesService();
    await notes.init();
    final players = ['Alice', 'Bob', 'Cleo'];
    await notes.ensureDefaultPositions(players, board,
        settings.characterKnobSize, layoutSettings: settings);

    await notes.setPlayerPosition(
        'Alice', const Offset(15, 27), board, settings.characterKnobSize);
    expect(notes.needsPositionSync(
      players, board, settings.characterKnobSize, layoutSettings: settings,
    ), isFalse);
    await notes.ensureDefaultPositions(players, board,
        settings.characterKnobSize, layoutSettings: settings);
    expect(notes.positionOf('Alice'), const Offset(15, 27));

    await settings.setRadiusX(settings.radiusX + 7, persist: false);
    expect(notes.needsPositionSync(
      players, board, settings.characterKnobSize, layoutSettings: settings,
    ), isTrue);
    await notes.ensureDefaultPositions(players, board,
        settings.characterKnobSize, layoutSettings: settings);
    expect(notes.positionOf('Alice'), isNot(const Offset(15, 27)));
    expect(notes.needsPositionSync(
      players, board, settings.characterKnobSize, layoutSettings: settings,
    ), isFalse);

    await notes.setPlayerPosition(
        'Alice', const Offset(12, 35), board, settings.characterKnobSize);
    await notes.resetPositions(players, board, settings.characterKnobSize,
        layoutSettings: settings);
    expect(notes.positionOf('Alice'), isNot(const Offset(12, 35)));
  });

  test('existing circular note positions migrate when layout is first applied',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'role_notes_player_positions':
          '{"Alice":{"dx":10.0,"dy":10.0},"Bob":{"dx":20.0,"dy":20.0}}',
    });
    const board = Size(360, 652);
    final settings = SettingsService();
    await settings.initialized;
    final notes = RoleNotesService();
    await notes.init();
    expect(notes.needsPositionSync(
      ['Alice', 'Bob'], board, settings.characterKnobSize,
      layoutSettings: settings,
    ), isTrue);
    await notes.ensureDefaultPositions(
      ['Alice', 'Bob'], board, settings.characterKnobSize,
      layoutSettings: settings,
    );
    expect(notes.positionOf('Alice'), isNot(const Offset(10, 10)));
    expect(notes.positionOf('Bob'), isNot(const Offset(20, 20)));
  });
}
