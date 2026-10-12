import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> rawCatalog;
  late List<Character> catalog;

  setUpAll(() async {
    rawCatalog = (jsonDecode(
      await rootBundle.loadString('assets/characters/en.json'),
    ) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    catalog = rawCatalog.map(Character.fromJson).toList(growable: false);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Character role(String roleId, {String? id, String? playerName}) {
    final source = rawCatalog.singleWhere((item) => item['roleId'] == roleId);
    return Character.fromJson({
      ...source,
      'id': id ?? '$roleId-instance',
      'playerName': playerName ?? roleId,
    });
  }

  test('all 123 English chronicle schemas and recursive fields parse', () {
    expect(rawCatalog, hasLength(181));
    final configured = rawCatalog
        .where((character) => character['chronicle'] != null)
        .toList();
    expect(configured, hasLength(123));
    expect(
      configured.where((character) {
        final chronicle = character['chronicle'] as Map;
        return (chronicle['firstNight'] as List?)?.isNotEmpty == true ||
            (chronicle['otherNights'] as List?)?.isNotEmpty == true;
      }),
      hasLength(63),
    );

    const knownTypes = {
      'number',
      'yesNo',
      'player',
      'players',
      'character',
      'characters',
      'choice',
      'text',
      'form',
    };

    int rawDefinitionCount(dynamic value) {
      if (value is! List) return 0;
      var count = 0;
      for (final raw in value.whereType<Map>()) {
        expect(knownTypes, contains(raw['type']), reason: raw.toString());
        count++;
        if (raw['type'] == 'form') {
          count += rawDefinitionCount(raw['fields']);
        }
      }
      return count;
    }

    int parsedDefinitionCount(List<ChronicleInputDefinition> definitions) =>
        definitions.fold(
          0,
          (count, definition) =>
              count + 1 + parsedDefinitionCount(definition.fields),
        );

    void compareDefinitions(
      List<dynamic> rawDefinitions,
      List<ChronicleInputDefinition> parsedDefinitions,
      String reason,
    ) {
      expect(parsedDefinitions, hasLength(rawDefinitions.length),
          reason: reason);
      for (var index = 0; index < rawDefinitions.length; index++) {
        final raw = Map<String, dynamic>.from(rawDefinitions[index] as Map);
        final parsed = parsedDefinitions[index];
        expect(parsed.id, raw['id'], reason: reason);
        expect(parsed.type.name, raw['type'], reason: reason);
        expect(parsed.label, raw['label'], reason: reason);
        expect(parsed.onlyIfApplicable, raw['when'] == 'onlyIfApplicable',
            reason: reason);
        expect(parsed.night, raw['night'], reason: reason);
        expect(parsed.repeatable, raw['repeatable'] == true, reason: reason);
        expect(parsed.min, raw['min'], reason: reason);
        expect(parsed.max, raw['max'], reason: reason);
        if (raw['count'] != null) {
          expect(parsed.minCount, raw['count'], reason: reason);
          expect(parsed.maxCount, raw['count'], reason: reason);
        } else {
          expect(parsed.minCount, raw['minCount'], reason: reason);
          expect(parsed.maxCount, raw['maxCount'], reason: reason);
        }
        final rawOptions = (raw['options'] as List<dynamic>?) ?? const [];
        expect(parsed.options, hasLength(rawOptions.length), reason: reason);
        for (var optionIndex = 0;
            optionIndex < rawOptions.length;
            optionIndex++) {
          final rawOption = rawOptions[optionIndex] as Map;
          expect(parsed.options[optionIndex].value, rawOption['value'],
              reason: reason);
          expect(parsed.options[optionIndex].label, rawOption['label'],
              reason: reason);
        }
        compareDefinitions(
          (raw['fields'] as List<dynamic>?) ?? const [],
          parsed.fields,
          '$reason.${parsed.id}',
        );
      }
    }

    for (final rawCharacter in configured) {
      final raw = rawCharacter['chronicle'] as Map;
      final parsed = ChronicleSchema.fromJson(raw);
      expect(parsed, isNotNull, reason: rawCharacter['roleId'] as String);
      expect(
        parsedDefinitionCount(parsed!.firstNight),
        rawDefinitionCount(raw['firstNight']),
        reason: '${rawCharacter['roleId']} firstNight',
      );
      expect(
        parsedDefinitionCount(parsed.otherNights),
        rawDefinitionCount(raw['otherNights']),
        reason: '${rawCharacter['roleId']} otherNights',
      );
      expect(
        parsed.auto.every((item) => item == 'nightStep' || item == 'quickFlow'),
        isTrue,
        reason: rawCharacter['roleId'] as String,
      );
      final rawFirst = (raw['firstNight'] as List<dynamic>?) ?? const [];
      final rawOther = (raw['otherNights'] as List<dynamic>?) ?? const [];
      compareDefinitions(
        rawFirst,
        parsed.firstNight,
        '${rawCharacter['roleId']}.firstNight',
      );
      compareDefinitions(
        rawOther,
        parsed.otherNights,
        '${rawCharacter['roleId']}.otherNights',
      );
      expect(
        parsed.definitionsForNight(1).map((item) => item.id),
        rawFirst
            .where((item) =>
                item['night'] == null || (item['night'] as num).toInt() == 1)
            .map((item) => item['id']),
        reason: '${rawCharacter['roleId']} night 1 assignment',
      );
      for (final round in [2, 3, 4]) {
        expect(
          parsed.definitionsForNight(round).map((item) => item.id),
          rawOther
              .where((item) =>
                  item['night'] == null ||
                  (item['night'] as num).toInt() == round)
              .map((item) => item['id']),
          reason: '${rawCharacter['roleId']} night $round assignment',
        );
      }
    }
    expect(catalog.where((character) => character.chronicle != null),
        hasLength(123));
  });

  test('night, phase, conditional and repeatable metadata stay distinct', () {
    final fortune = role('fortuneteller').chronicle!;
    expect(fortune.definitionsForNight(1).single.id, 'fortuneReading');
    expect(fortune.definitionsForNight(2).single.id, 'fortuneReading');

    final summoner = role('summoner').chronicle!;
    expect(summoner.definitionsForNight(2), isEmpty);
    expect(summoner.definitionsForNight(3).single.id, 'summonedDemon');
    expect(summoner.definitionsForNight(3).single.onlyIfApplicable, isTrue);

    final librarian = role('librarian').chronicle!;
    expect(librarian.firstNight.single.onlyIfApplicable, isTrue);
    expect(role('snitch').chronicle!.firstNight.single.repeatable, isTrue);
    expect(role('kazali').chronicle!.firstNight.single.repeatable, isTrue);
  });

  test('onlyIfApplicable is offered but not created by a night visit',
      () async {
    final service = ChronicleService();
    await service.ready;
    final librarian = role('librarian');
    await service.startNewGame([librarian]);
    await service.recordNightVisit(librarian, 1);

    expect(
      service.activeChronicle!.events.where(
        (event) => event.type == ChronicleEventType.nightInformation,
      ),
      isEmpty,
    );
    final optional = service.optionalDefinitions(
      round: 1,
      catalog: catalog,
    );
    expect(optional.single.definition.id, 'noOutsidersShown');
  });

  test('repeatable values get stable independent entry ids', () async {
    final service = ChronicleService();
    await service.ready;
    final snitch = role('snitch');
    await service.startNewGame([snitch]);
    await service.recordNightVisit(snitch, 1);
    final event = service.activeChronicle!.events.singleWhere(
      (item) => item.type == ChronicleEventType.nightInformation,
    );

    final first = await service.saveInformationEntry(
      eventId: event.id,
      values: const {'recipient': 'first'},
    );
    final second = await service.saveInformationEntry(
      eventId: event.id,
      values: const {'recipient': 'second'},
    );

    expect(first, isNot(second));
    final savedEvent = service.activeChronicle!.events.singleWhere(
      (item) => item.id == event.id,
    );
    expect(savedEvent.informationEntries, hasLength(2));
  });

  test('manual values can be changed after the chronicle was archived',
      () async {
    final service = ChronicleService();
    await service.ready;
    final empath = role('empath');
    await service.startNewGame([empath]);
    await service.recordNightVisit(empath, 2);
    final event = service.activeChronicle!.events.singleWhere(
      (item) => item.type == ChronicleEventType.nightInformation,
    );
    final entryId = await service.saveInformationEntry(
      eventId: event.id,
      values: const {'empathCount': 2},
    );
    await service.archiveCurrent();

    await service.saveInformationEntry(
      eventId: event.id,
      entryId: entryId,
      values: const {'empathCount': 1},
      archived: true,
    );

    final restored = ChronicleService();
    await restored.ready;
    final restoredEvent = restored.lastChronicle!.events.singleWhere(
      (item) => item.id == event.id,
    );
    expect(
      restoredEvent.informationEntries.single['values']['empathCount'],
      1,
    );
  });

  test('QuickFlow target is not interpreted as death or actual effect',
      () async {
    final service = ChronicleService();
    await service.ready;
    final imp = role('imp');
    final target = role('chef', id: 'target', playerName: 'Target');
    await service.startNewGame([imp, target]);

    await service.recordReminderAssignment(
      target: target,
      token: imp.tokens.first,
      phase: ChroniclePhase.night,
      round: 2,
      source: 'quickFlow',
      quickFlowStepId: 'attack',
      quickFlowOwner: imp,
    );

    final events = service.activeChronicle!.events;
    expect(
      events
          .where((event) => event.type == ChronicleEventType.reminderAssigned),
      hasLength(1),
    );
    expect(
      events
          .where((event) => event.type == ChronicleEventType.lifeStatusChanged),
      isEmpty,
    );
  });

  test('legacy single-input chronicle events migrate without data loss',
      () async {
    final chef = role('chef', playerName: 'Alex');
    final log = ChronicleLog(
      gameId: 'legacy-game',
      startedAt: DateTime(2025),
      events: [
        ChronicleEvent(
          id: 'night-info:1:${chef.id}',
          timestamp: DateTime(2025),
          type: ChronicleEventType.nightInformation,
          phase: ChroniclePhase.night,
          round: 1,
          character: ChronicleCharacterSnapshot.fromCharacter(chef),
          details: const {
            'schema': {
              'input': {
                'type': 'number',
                'min': 0,
                'max': 3,
              },
            },
            'number': 2,
            'completed': true,
          },
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'chronicle_active_v1': jsonEncode(log.toJson()),
    });

    final service = ChronicleService();
    await service.ready;

    final migrated = service.activeChronicle!.events.single;
    expect(migrated.inputDefinition?.type, ChronicleInputType.number);
    expect(migrated.informationEntries.single['values']['legacyInput'], 2);
  });
}
