import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const translatedInThisPass = <String>{
  'alsaahir',
  'amnesiac',
  'atheist',
  'balloonist',
};

Future<List<Map<String, dynamic>>> loadRoles(String locale) async {
  final raw = await File('assets/characters/$locale.json').readAsString();
  return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
}

String roleIdOf(Map<String, dynamic> role) {
  final roleId = role['roleId'] as String?;
  if (roleId != null && roleId.isNotEmpty) {
    return roleId;
  }
  return (role['image'] as String)
      .replaceFirst(RegExp(r'^Icon_'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toLowerCase();
}

Map<String, dynamic> technicalRoleData(Map<String, dynamic> role) {
  return {
    'image': role['image'],
    'fraction': role['fraction'],
    'gameset': role['gameset'],
    'wakeUpEveryNight': role['wakeUpEveryNight'],
    'wakeUpAtFirstNight': role['wakeUpAtFirstNight'],
    'nightStateNumbersFirstNight': role['nightStateNumbersFirstNight'],
    'nightStateNumbersOtherNights': role['nightStateNumbersOtherNights'],
    'tokens': (role['tokens'] as List<dynamic>).map((token) {
      final value = token as Map<String, dynamic>;
      return Map<String, dynamic>.from(value)..remove('name');
    }).toList(),
  };
}

void main() {
  test('the completed German catalog contains every English role once',
      () async {
    final english = await loadRoles('en');
    final german = await loadRoles('de');
    final englishIds = english.map(roleIdOf).toSet();
    final germanIds = german.map(roleIdOf).toList();
    final missing = englishIds.difference(germanIds.toSet()).toList()..sort();

    expect(german, hasLength(english.length));
    expect(germanIds.toSet(), hasLength(germanIds.length));
    expect(germanIds, containsAll(translatedInThisPass));
    expect(missing, isEmpty);
  });

  test('translated roles preserve the English technical structure', () async {
    final englishById = {
      for (final role in await loadRoles('en')) roleIdOf(role): role,
    };
    final germanById = {
      for (final role in await loadRoles('de')) roleIdOf(role): role,
    };

    for (final id in translatedInThisPass) {
      final english = englishById[id]!;
      final german = germanById[id]!;
      expect(german.keys.toSet(), equals(english.keys.toSet()));
      expect(technicalRoleData(german), equals(technicalRoleData(english)));
      expect(german['descriptionShort'],
          isNot(equals(english['descriptionShort'])));
      expect(
          german['descriptionLong'], isNot(equals(english['descriptionLong'])));
      expect(german['howToRun'], isNot(equals(english['howToRun'])));
    }
  });
}
