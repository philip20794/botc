import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/role_multiplicity.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, dynamic>> catalog;

  setUpAll(() async {
    final json = (jsonDecode(
        await rootBundle.loadString('assets/characters/de.json')) as List)
        .cast<Map<String, dynamic>>();
    catalog = {for (final role in json) role['roleId'] as String: role};
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Village Idiot uses 1, 2, 3 and a random value is always valid', () {
    expect(RoleMultiplicity.allowedCounts('villageidiot', 10), [1, 2, 3]);
    expect(RoleMultiplicity.allowedCounts(
        'villageidiot', 10, availableSlots: 2), [1, 2]);
    final random = Random(17);
    final sampled = <int>{};
    for (var i = 0; i < 150; i++) {
      sampled.add(RoleMultiplicity.randomCount('villageidiot', 10,
          random: random));
    }
    expect(sampled, {1, 2, 3});
  });

  test('Legion setup is always a majority; random picks valid quantities', () {
    expect(RoleMultiplicity.allowedCounts('legion', 5), [3, 4]);
    expect(RoleMultiplicity.allowedCounts('legion', 10), [6, 7, 8, 9]);
    expect(RoleMultiplicity.allowedCounts('legion', 15).first, 8);
    final random = Random(8);
    for (var players = 5; players <= 15; players++) {
      for (var i = 0; i < 35; i++) {
        final count = RoleMultiplicity.randomCount('legion', players,
            random: random);
        expect(count > players / 2, isTrue);
        expect(count, lessThan(players));
      }
    }
  });

  test('Riot and Farmer never allow Storyteller-selected setup quantity', () {
    expect(RoleMultiplicity.storytellerChooses('riot'), isFalse);
    expect(RoleMultiplicity.storytellerChooses('farmer'), isFalse);
    expect(RoleMultiplicity.automaticCount('riot'), 1);
    expect(RoleMultiplicity.automaticCount('farmer'), 1);
    expect(RoleMultiplicity.allowedCounts('riot', 10), [1]);
    expect(RoleMultiplicity.allowedCounts('farmer', 10), [1]);
  });

  test('character service persists exact setup number without mutating catalog',
      () async {
    final service = CharacterService();
    await service.init();
    final idiot = Character.fromJson({...catalog['villageidiot']!});
    service.addCharacter(idiot, exemplars: 2, playerCount: 10);
    expect(service.gameCharacters.where((x) => x.roleId == 'villageidiot')
        .length, 2);
    expect(idiot.numberOfExemplars, 1);
    expect(service.gameCharacters.map((x) => x.id).toSet().length,
        service.gameCharacters.length);
    service.addCharacter(idiot, exemplars: 3, playerCount: 10);
    expect(service.gameCharacters.length, 2);
    service.removeCharacter(idiot);
    expect(service.gameCharacters, isEmpty);

    final riot = Character.fromJson({...catalog['riot']!});
    service.addCharacter(riot, exemplars: 8, playerCount: 10);
    expect(service.gameCharacters.where((x) => x.roleId == 'riot').length, 1);
    expect(() => service.addCharacter(idiot, exemplars: 4, playerCount: 10),
        throwsArgumentError);
  });

  test('catalog contains current Riot and Farmer conversion QuickFlow steps',
      () {
    final riot = Character.fromJson({...catalog['riot']!});
    final farmer = Character.fromJson({...catalog['farmer']!});
    expect(riot.numberOfExemplars, 1);
    expect(farmer.numberOfExemplars, 1);
    expect(riot.quickFlow.otherNights.single.type.name, 'roleChange');
    expect(riot.quickFlow.otherNights.single.nightConstraint, 'night3');
    expect(farmer.quickFlow.otherNights.last.targetRoleId, 'farmer');
  });
}
