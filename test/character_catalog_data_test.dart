import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<Map<String, dynamic>> loadEnglishRole(String name) async {
  final file = File('assets/characters/en.json');
  final roles = jsonDecode(await file.readAsString()) as List<dynamic>;
  return (roles.cast<Map<String, dynamic>>().singleWhere(
        (role) => role['name'] == name,
      ));
}

Future<Map<String, dynamic>> loadGermanRole(String name) async {
  final file = File('assets/characters/de.json');
  final roles = jsonDecode(await file.readAsString()) as List<dynamic>;
  return (roles.cast<Map<String, dynamic>>().singleWhere(
        (role) => role['name'] == name,
      ));
}

void main() {
  test('Wizard has a source-backed long description', () async {
    final wizard = await loadEnglishRole('Wizard');

    expect(wizard['descriptionLong'], isNotEmpty);
    expect(wizard['descriptionLong'], contains('makes a wish'));
    expect(wizard['descriptionLong'], contains('balancing price'));
  });

  test('conditional night roles have no unconditional night slot', () async {
    for (final name in ['Cannibal', 'Choirboy', 'King']) {
      final role = await loadEnglishRole(name);

      expect(role['wakeUpAtFirstNight'], isFalse, reason: name);
      expect(role['wakeUpEveryNight'], isFalse, reason: name);
      expect(role['nightStateNumbersFirstNight'], isEmpty, reason: name);
      expect(role['nightStateNumbersOtherNights'], isEmpty, reason: name);
    }
  });

  test('Balloonist has source-backed storyteller instructions', () async {
    final balloonist = await loadEnglishRole('Balloonist');

    expect(balloonist['howToRun'], isNot('howToRun'));
    expect(balloonist['howToRun'], contains('may add an Outsider'));
    expect(balloonist['howToRun'], contains('KNOW reminder'));
    expect(
      RegExp(r'character type.{0,80}(differs|different)', caseSensitive: false)
          .hasMatch(balloonist['howToRun'] as String),
      isTrue,
    );
  });

  test('Philosopher reminder tokens use the existing canonical asset',
      () async {
    final philosopher = await loadGermanRole('Philosopher');
    final tokenImages = (philosopher['tokens'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((token) => token['image'])
        .toList();

    expect(
        tokenImages, orderedEquals(['Icon_philosopher', 'Icon_philosopher']));
    expect(File('assets/images/characters/Icon_philosopher.png').existsSync(),
        isTrue);
  });

  test('Traveller night slots retain their deliberate night order', () async {
    final english = await Future.wait([
      loadEnglishRole('Barista'),
      loadEnglishRole('Bone Collector'),
      loadEnglishRole('Bureaucrat'),
      loadEnglishRole('Harlot'),
      loadEnglishRole('Thief'),
    ]);
    final german = await Future.wait([
      loadGermanRole('Barista'),
      loadGermanRole('Bone Collector'),
      loadGermanRole('Bureaucrat'),
      loadGermanRole('Harlot'),
      loadGermanRole('Thief'),
    ]);

    const expectedSlots = <String, List<double>>{
      'Barista': [22.2],
      'Bone Collector': [20.2],
      'Bureaucrat': [14.1, 14.1],
      'Harlot': [21.2],
      'Thief': [15.1, 15.1],
    };
    for (final role in [...english, ...german]) {
      expect(role['wakeUpEveryNight'], isTrue);
      final slots = [
        ...(role['nightStateNumbersFirstNight'] as List<dynamic>),
        ...(role['nightStateNumbersOtherNights'] as List<dynamic>),
      ].cast<num>().map((slot) => slot.toDouble()).toList();
      expect(slots, expectedSlots[role['name']],
          reason: role['name'] as String);
    }
  });

  test('Evil Twin keeps the shared Minion information slot', () async {
    final evilTwin = await loadGermanRole('Evil Twin');

    expect(evilTwin['nightStateNumbersFirstNight'], contains(2.0));
    expect(evilTwin['nightStateNumbersFirstNight'], contains(6.2));
  });
}
