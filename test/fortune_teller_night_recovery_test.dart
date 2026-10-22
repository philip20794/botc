import 'dart:convert';

import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved Fortune Teller wakes after day deaths on later nights', () async {
    final catalog = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    Map<String, dynamic> role(String roleId, String id, String playerName) => {
          ...catalog.singleWhere((item) => item['roleId'] == roleId),
          'id': id,
          'playerName': playerName,
        };

    final staleFortuneTeller = role('fortuneteller', 'ft-1', 'Alice')
      // Old persisted metadata must not override the current role catalog.
      ..['nightWake'] = {'otherNightsRequireNoDeathsPreviousDay': true}
      ..['wakeUpEveryNight'] = false;
    final washerwoman = role('washerwoman', 'washer-1', 'Bob');
    final savedCharacters = jsonEncode([staleFortuneTeller, washerwoman]);
    SharedPreferences.setMockInitialValues({
      'character_list': savedCharacters,
      'character_list_backup': savedCharacters,
    });

    final characters = CharacterService();
    await characters.init();
    expect(
      characters.gameCharacters.first.nightWake
          .otherNightsRequireNoDeathsPreviousDay,
      isTrue,
    );
    await characters.loadAllCharactersFromJson(const Locale('de'));

    final fortuneTeller = characters.gameCharacters.first;
    expect(fortuneTeller.roleId, 'fortuneteller');
    expect(fortuneTeller.id, 'ft-1');
    expect(fortuneTeller.playerName, 'Alice');
    expect(fortuneTeller.wakeUpEveryNight, isTrue);
    expect(fortuneTeller.nightWake.isEmpty, isTrue);
    expect(characters.gameCharactersBackup.first.nightWake.isEmpty, isTrue);

    final prefs = await SharedPreferences.getInstance();
    for (final key in ['character_list', 'character_list_backup']) {
      final stored = (jsonDecode(prefs.getString(key)!) as List).first as Map;
      expect(stored['id'], 'ft-1');
      expect(stored['playerName'], 'Alice');
      expect(stored['wakeUpEveryNight'], isTrue);
      expect(stored.containsKey('nightWake'), isFalse);
    }

    final scripts = ScriptService();
    final nightOrder = NightOrderService();
    await Future.wait([scripts.ready, nightOrder.ready]);
    final game = GameStateService(
      scriptService: scripts,
      nightOrderService: nightOrder,
    );
    await game.ready;
    final active = characters.gameCharacters;
    await game.startNewGame(active);

    Future<void> advanceUntil(String targetStep) async {
      for (var i = 0; i < 30 && game.currentNightStepId != targetStep; i++) {
        await game.nextNightState(active);
      }
      expect(game.currentNightStepId, targetStep);
    }

    // Finish the first night, then execute a different player on day one.
    await advanceUntil('day');
    await game.toggleCharacterAlive(active.last);
    expect(game.isCharacterAlive(fortuneTeller), isTrue);

    for (final night in [2, 3]) {
      await game.nextNightState(active);
      expect(game.nightCount, night);
      await advanceUntil('role:fortuneteller:ft-1');
      expect(game.isCharacterAwake(fortuneTeller), isTrue);
      await advanceUntil('day');
    }
  });
}
