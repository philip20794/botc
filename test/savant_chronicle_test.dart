import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_summary.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const actor = ChronicleCharacterSnapshot(
    characterId: 'savant-1',
    roleId: 'savant',
    roleName: 'Savant',
    playerName: 'Alice',
    image: 'Icon_savant',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save, edit, restart, remove and project independent day entries', () async {
    final service = ChronicleService();
    await service.ready;
    await service.startNewGame([]);
    final first = await service.upsertSavantStatement(
      round: 1,
      actor: actor,
      statement: {'template': 'A [Number]', 'rendered': 'A 1'},
    );
    final second = await service.upsertSavantStatement(
      round: 1,
      actor: actor,
      statement: {'template': 'B', 'rendered': 'B'},
    );
    expect(first, isNotNull);
    expect(second, isNot(first));

    await service.upsertSavantStatement(
      eventId: first,
      round: 1,
      actor: actor,
      statement: {'template': 'A [Number]', 'rendered': 'A 2'},
    );
    final restarted = ChronicleService();
    await restarted.ready;
    final selected = restarted.activeChronicle!.events
        .where((event) => event.type == ChronicleEventType.savantStatement)
        .toList();
    expect(selected, hasLength(2));
    expect(selected.first.details['statement']['rendered'], 'A 2');
    expect(const ChronicleSummaryProjector()
        .project(restarted.activeChronicle!.events)
        .where((entry) => entry.phase == ChroniclePhase.day), hasLength(2));

    await restarted.removeSavantStatement(first!);
    expect(restarted.activeChronicle!.events
        .where((event) => event.type == ChronicleEventType.savantStatement),
        hasLength(1));
    await restarted.archiveCurrent();
    expect(restarted.lastChronicle!.events.any(
        (event) => event.type == ChronicleEventType.savantStatement), isTrue);
    await restarted.startNewGame([]);
    expect(restarted.activeChronicle!.events.any(
        (event) => event.type == ChronicleEventType.savantStatement), isFalse);
  });
}
