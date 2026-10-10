import 'dart:convert';
import 'dart:io';

import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter_test/flutter_test.dart';

const officialRoleIdsAtF10cd02 = <String>{
  'acrobat',
  'alchemist',
  'alhadikhia',
  'alsaahir',
  'amnesiac',
  'angel',
  'apprentice',
  'artist',
  'assassin',
  'atheist',
  'balloonist',
  'banshee',
  'barber',
  'barista',
  'baron',
  'beggar',
  'bigwig',
  'bishop',
  'boffin',
  'bonecollector',
  'boomdandy',
  'bootlegger',
  'bountyhunter',
  'buddhist',
  'bureaucrat',
  'butcher',
  'butler',
  'cacklejack',
  'cannibal',
  'cerenovus',
  'chambermaid',
  'chef',
  'choirboy',
  'clockmaker',
  'courtier',
  'cultleader',
  'damsel',
  'deusexfiasco',
  'deviant',
  'devilsadvocate',
  'djinn',
  'doomsayer',
  'dreamer',
  'drunk',
  'duchess',
  'empath',
  'engineer',
  'eviltwin',
  'exorcist',
  'fanggu',
  'farmer',
  'fearmonger',
  'ferryman',
  'fibbin',
  'fiddler',
  'fisherman',
  'flowergirl',
  'fool',
  'fortuneteller',
  'gambler',
  'gangster',
  'gardener',
  'general',
  'gnome',
  'goblin',
  'godfather',
  'godofug',
  'golem',
  'goon',
  'gossip',
  'grandmother',
  'gunslinger',
  'harlot',
  'harpy',
  'hatter',
  'hellslibrarian',
  'heretic',
  'hermit',
  'highpriestess',
  'hindu',
  'huntsman',
  'imp',
  'innkeeper',
  'investigator',
  'judge',
  'juggler',
  'kazali',
  'king',
  'klutz',
  'knaves',
  'knight',
  'legion',
  'leviathan',
  'librarian',
  'lilmonsta',
  'lleech',
  'lordoftyphon',
  'lunatic',
  'lycanthrope',
  'magician',
  'marionette',
  'mastermind',
  'mathematician',
  'matron',
  'mayor',
  'mezepheles',
  'minstrel',
  'monk',
  'moonchild',
  'mutant',
  'nightwatchman',
  'noble',
  'nodashii',
  'ogre',
  'ojo',
  'oracle',
  'organgrinder',
  'pacifist',
  'philosopher',
  'pithag',
  'pixie',
  'plaguedoctor',
  'po',
  'poisoner',
  'politician',
  'pope',
  'poppygrower',
  'preacher',
  'princess',
  'professor',
  'psychopath',
  'pukka',
  'puzzlemaster',
  'ravenkeeper',
  'recluse',
  'revolutionary',
  'riot',
  'sage',
  'sailor',
  'saint',
  'savant',
  'scapegoat',
  'scarletwoman',
  'seamstress',
  'sentinel',
  'shabaloth',
  'shugenja',
  'slayer',
  'snakecharmer',
  'snitch',
  'soldier',
  'spiritofivory',
  'spy',
  'steward',
  'stormcatcher',
  'summoner',
  'sweetheart',
  'tealady',
  'thief',
  'tinker',
  'tor',
  'towncrier',
  'toymaker',
  'undertaker',
  'ventriloquist',
  'vigormortis',
  'villageidiot',
  'virgin',
  'vizier',
  'vortox',
  'voudon',
  'washerwoman',
  'widow',
  'witch',
  'wizard',
  'wraith',
  'xaan',
  'yaggababble',
  'zealot',
  'zenomancer',
  'zombuul',
};

const addedRoleTeams = <String, String>{
  'bigwig': 'loric',
  'cacklejack': 'traveller',
  'deusexfiasco': 'fabled',
  'godofug': 'loric',
  'hermit': 'outsider',
  'hindu': 'loric',
  'knaves': 'loric',
  'pope': 'loric',
  'princess': 'townsfolk',
  'tor': 'loric',
  'ventriloquist': 'loric',
  'wraith': 'minion',
  'zenomancer': 'loric',
};

const addedRoleReminderNames = <String, List<String>>{
  'bigwig': [],
  'cacklejack': ['Not Me'],
  'deusexfiasco': ['Whoopsie'],
  'godofug': ['Hat'],
  'hermit': ['1', '2', '3'],
  'hindu': [],
  'knaves': [],
  'pope': [],
  'princess': ["Doesn't Kill"],
  'tor': [],
  'ventriloquist': ['Mad'],
  'wraith': [],
  'zenomancer': ['Goal', 'Goal', 'Goal'],
};

Future<List<Map<String, dynamic>>> loadEnglishRoles() async {
  final raw = await File('assets/characters/en.json').readAsString();
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

void main() {
  test('English catalogue exactly matches official role IDs at f10cd02',
      () async {
    final roles = await loadEnglishRoles();
    final localRoleIds = roles.map(roleIdOf).toList();

    expect(roles, hasLength(181));
    expect(localRoleIds.toSet(), hasLength(localRoleIds.length));
    expect(localRoleIds.toSet(), equals(officialRoleIdsAtF10cd02));
  });

  test('new official roles retain team and reminder metadata', () async {
    final rolesById = {
      for (final role in await loadEnglishRoles()) roleIdOf(role): role,
    };

    for (final entry in addedRoleTeams.entries) {
      final role = rolesById[entry.key]!;
      expect(role['roleId'], entry.key);
      expect(role['fraction'], entry.value);
      expect(role['descriptionShort'], isNotEmpty);
      expect(
        (role['tokens'] as List<dynamic>)
            .map((token) => (token as Map<String, dynamic>)['name'])
            .toList(),
        addedRoleReminderNames[entry.key],
      );
    }
  });

  test('catalogue records have a valid image asset or the explicit fallback',
      () async {
    for (final role in await loadEnglishRoles()) {
      expect(role['descriptionShort'], isA<String>());
      expect(role['tokens'], isA<List<dynamic>>());
      expect(role['gameset'], isA<List<dynamic>>());
      expect(role['wakeUpAtFirstNight'], isA<bool>());
      expect(role['wakeUpEveryNight'], isA<bool>());
      expect(role['nightStateNumbersFirstNight'], isA<List<dynamic>>());
      expect(role['nightStateNumbersOtherNights'], isA<List<dynamic>>());

      final image = role['image'] as String;
      expect(File(roleImageAssetPath(image)).existsSync(), isTrue);
    }
  });
}
