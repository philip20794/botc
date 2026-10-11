import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<GameStateService> createService() async {
    final scripts = ScriptService();
    await scripts.ready;
    final service = GameStateService(scriptService: scripts);
    await service.ready;
    return service;
  }

  Character character(String id, Token token) => Character(
        id: id,
        roleId: 'role-$id',
        name: id,
        descriptionShort: '',
        descriptionLong: '',
        howToRun: '',
        image: 'Icon_$id',
        fraction: Fraction.townsfolk,
        tokens: <Token>[token],
        wakeUpEveryNight: false,
        wakeUpAtFirstNight: false,
        gameset: const <Gameset>[Gameset.trouble_brewing],
        nightStateNumbersFirstNight: const <double>[],
        nightStateNumbersOtherNights: const <double>[],
        tipsAndTricks: const <String>[],
        bluffs: const <String>[],
      );

  Token token(String suffix) => Token(
        name: 'Reminder $suffix',
        image: 'Icon_reminder_$suffix',
      );

  test('uses only active characters as reminder-token inventory', () async {
    final service = await createService();
    final active = character('active', token('mad'));
    final backup = active.copyWith();

    final tokens = service.getAllTokensInGame(<Character>[active]);

    expect(tokens, hasLength(1));
    expect(tokens.single, same(active.tokens.single));
    expect(identical(active, backup), isFalse);
  });

  test('keeps genuine duplicate reminders as separate inventory occurrences',
      () async {
    final service = await createService();
    final first = character('first', token('died-today'));
    final second = character('second', token('died-today'));

    final tokens = service.getAllTokensInGame(<Character>[first, second]);

    expect(tokens, hasLength(2));
    expect(tokens.where((item) => item.name == 'Reminder died-today'),
        hasLength(2));
  });

  test('assignment, removal and reopening preserve the exact token count',
      () async {
    final service = await createService();
    final first = character('first', token('mad'));
    final second = character('second', token('mad'));
    final characters = <Character>[first, second];

    expect(service.getAllTokensInGame(characters), hasLength(2));
    await service.addTokenToCharacter(characters, first, first.tokens.single);

    expect(service.tokensOfCharacter(first), hasLength(1));
    expect(service.getAllTokensInGame(characters), hasLength(2));
    expect(service.unsedGameTokens, hasLength(1));
    expect(service.isTokenUsed(first.tokens.single), isTrue);

    await service.removeTokenFromCharacter(
        first, service.tokensOfCharacter(first).single);

    expect(service.tokensOfCharacter(first), isEmpty);
    expect(service.getAllTokensInGame(characters), hasLength(2));
    expect(service.unsedGameTokens, hasLength(2));
  });

  test('persisted assignments consume one matching inventory occurrence',
      () async {
    final original = await createService();
    final originalCharacter = character('first', token('guess-used'));
    await original.addTokenToCharacter(<Character>[originalCharacter],
        originalCharacter, originalCharacter.tokens.single);

    final restored = await createService();
    final restoredCharacter = character('first', token('guess-used'));
    final tokens = restored.getAllTokensInGame(<Character>[restoredCharacter]);

    expect(tokens, hasLength(1));
    expect(restored.tokensOfCharacter(restoredCharacter), hasLength(1));
    expect(restored.isTokenUsed(restoredCharacter.tokens.single), isTrue);
    expect(restored.tokensOfCharacter(restoredCharacter).single,
        same(restoredCharacter.tokens.single));
  });

  test('random reminder assignment never adds the same token twice', () async {
    final service = await createService();
    final characters = <Character>[
      character('first', token('one')),
      character('second', token('two')),
      character('third', token('three')),
    ];

    await service.addRandomUnusedTokensToRandomCharacters(characters);

    for (final selectedCharacter in characters) {
      expect(service.tokensOfCharacter(selectedCharacter), hasLength(1));
    }
    expect(
      characters
          .expand(service.tokensOfCharacter)
          .map((assignedToken) => assignedToken.image)
          .toSet(),
      hasLength(3),
    );
  });
}
