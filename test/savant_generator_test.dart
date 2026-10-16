import 'dart:convert';
import 'dart:typed_data';

import 'package:blood_on_the_clocktower/components/savant_generator.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestSavantBundle extends CachingAssetBundle {
  _TestSavantBundle({required this.english, required this.german});

  final List<String> english;
  final List<String> german;

  @override
  Future<ByteData> load(String key) async {
    final List<String> statements;
    switch (key) {
      case 'assets/savant/en.json':
        statements = english;
        break;
      case 'assets/savant/de.json':
        statements = german;
        break;
      default:
        throw FlutterError('Unexpected asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(statements))));
  }
}

Character _role(String roleId, Fraction fraction) => Character(
      id: roleId,
      roleId: roleId,
      name: roleId,
      descriptionShort: '',
      descriptionLong: '',
      howToRun: '',
      image: 'Icon_$roleId',
      fraction: fraction,
      tokens: const [],
      wakeUpEveryNight: false,
      wakeUpAtFirstNight: false,
      gameset: const [Gameset.trouble_brewing],
      nightStateNumbersFirstNight: const [],
      nightStateNumbersOtherNights: const [],
      tipsAndTricks: const [],
      bluffs: const [],
    );

Future<Widget> _createApp({
  required _TestSavantBundle bundle,
  bool withPlayers = true,
  bool withCharacters = true,
  bool withMinions = true,
  Locale locale = const Locale('en'),
}) async {
  final scripts = ScriptService();
  await scripts.ready;
  final game = GameStateService(scriptService: scripts);
  await game.ready;
  final characters = CharacterService();
  await characters.init();

  if (withPlayers) await game.addPlayerName('Alice');
  if (withCharacters) {
    characters.allCharacters.addAll([
      _role('monk', Fraction.townsfolk),
      _role('imp', Fraction.demon),
      if (withMinions) _role('poisoner', Fraction.minion),
    ]);
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: scripts),
      ChangeNotifierProvider.value(value: game),
      ChangeNotifierProvider.value(value: characters),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DefaultAssetBundle(
        bundle: bundle,
        child: const SavantGenerator(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('displays templates even without game data', (tester) async {
    final bundle = _TestSavantBundle(
      english: ['English statement.'],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withPlayers: false,
      withCharacters: false,
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('English statement.'), findsOneWidget);
    expect(find.text('No Savant statement available.'), findsNothing);
  });

  testWidgets('skips statements requiring unavailable game data',
      (tester) async {
    final bundle = _TestSavantBundle(
      english: [
        '[Player] was selected by [Minion].',
        '[Character] is in play.',
        'There was no starting Demon.',
      ],
      german: ['Es gab keinen ursprünglichen Dämon.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withPlayers: false,
      withCharacters: false,
    ));
    await tester.pumpAndSettle();

    expect(find.text('There was no starting Demon.'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('New statement'));
      await tester.pumpAndSettle();
      expect(find.text('There was no starting Demon.'), findsOneWidget);
      expect(find.textContaining('['), findsNothing);
    }
  });

  testWidgets('uses only templates supported by partial game data',
      (tester) async {
    final bundle = _TestSavantBundle(
      english: [
        '[Player] was selected.',
        '[Minion] is in play.',
        '[Character] woke last night.',
      ],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withPlayers: false,
    ));
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(find.textContaining('Alice'), findsNothing);
      expect(find.textContaining('['), findsNothing);
      expect(find.text('No Savant statement available.'), findsNothing);
      await tester.tap(find.text('New statement'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('skips minion and unknown placeholders when data is missing',
      (tester) async {
    final bundle = _TestSavantBundle(
      english: [
        '[Minion] was selected.',
        '[Unknown] did something.',
        '[Number] players woke last night.',
      ],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withMinions: false,
    ));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      expect(find.textContaining('players woke last night.'), findsOneWidget);
      expect(find.textContaining('['), findsNothing);
      await tester.tap(find.text('New statement'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('disables the random button when no template is usable',
      (tester) async {
    final bundle = _TestSavantBundle(
      english: ['[Player] was selected by [Minion].'],
      german: ['[Player] wurde ausgewählt.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withPlayers: false,
      withCharacters: false,
    ));
    await tester.pumpAndSettle();

    expect(find.text('No Savant statement available.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('can use role type placeholders without character data',
      (tester) async {
    final bundle = _TestSavantBundle(
      english: ['A [Character/Role Type] woke last night.'],
      german: ['Ein [Role Type] ist im Spiel.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      withPlayers: false,
      withCharacters: false,
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('woke last night.'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
    await tester.tap(find.text('DE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ist im Spiel.'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
  });

  testWidgets('replaces all supported placeholders', (tester) async {
    final bundle = _TestSavantBundle(
      english: [
        '[Player] [Character] [character] [Minion] [Demon] '
            '[Role Type] [Character/Role Type] [Number].',
      ],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(bundle: bundle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Alice'), findsOneWidget);
    expect(find.textContaining('['), findsNothing);
  });

  testWidgets('switches between DE and EN in the popup', (tester) async {
    final bundle = _TestSavantBundle(
      english: ['English statement.'],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(bundle: bundle));
    await tester.pumpAndSettle();

    expect(find.text('English statement.'), findsOneWidget);
    await tester.tap(find.text('DE'));
    await tester.pumpAndSettle();
    expect(find.text('Deutsche Aussage.'), findsOneWidget);
    expect(find.text('Neue Aussage'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('English statement.'), findsOneWidget);
  });

  testWidgets('uses app language as initial popup language', (tester) async {
    final bundle = _TestSavantBundle(
      english: ['English statement.'],
      german: ['Deutsche Aussage.'],
    );
    await tester.pumpWidget(await _createApp(
      bundle: bundle,
      locale: const Locale('de'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Deutsche Aussage.'), findsOneWidget);
    expect(find.text('Neue Aussage'), findsOneWidget);
  });

  testWidgets('new statement button avoids immediate repetition', (tester) async {
    final bundle = _TestSavantBundle(
      english: ['English first.', 'English second.'],
      german: ['Deutsch eins.', 'Deutsch zwei.'],
    );
    await tester.pumpWidget(await _createApp(bundle: bundle));
    await tester.pumpAndSettle();

    final firstWasShown = find.text('English first.').evaluate().isNotEmpty;
    await tester.tap(find.text('New statement'));
    await tester.pumpAndSettle();
    expect(
      find.text(firstWasShown ? 'English second.' : 'English first.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
