import 'dart:convert';

import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    await service.init();
    return service;
  }

  Character character(String roleId, Fraction fraction) => Character(
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

  test('demon bluffs persist as distinct role ids and old saves load empty',
      () async {
    final service = await createService();
    await service.setDemonBluffRoleIds(['washerwoman', 'librarian', 'chef']);

    final restored = await createService();
    expect(
      restored.demonBluffRoleIds,
      orderedEquals(['washerwoman', 'librarian', 'chef']),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      'demon_bluff_role_ids': jsonEncode(['imp', 'imp', '', 'poisoner']),
    });
    final migrated = await createService();
    expect(migrated.demonBluffRoleIds, orderedEquals(['imp', 'poisoner']));
  });

  test('bluffs reject selected or unsuitable roles and enforce a maximum of 3',
      () async {
    final service = await createService();

    expect(
      await service.toggleDemonBluff(
        'imp',
        isEligible: false,
        isGameCharacter: false,
      ),
      isFalse,
    );
    expect(
      await service.toggleDemonBluff(
        'washerwoman',
        isEligible: true,
        isGameCharacter: true,
      ),
      isFalse,
    );

    for (final roleId in ['washerwoman', 'librarian', 'chef']) {
      expect(
        await service.toggleDemonBluff(
          roleId,
          isEligible: true,
          isGameCharacter: false,
        ),
        isTrue,
      );
    }
    expect(
      await service.toggleDemonBluff(
        'empath',
        isEligible: true,
        isGameCharacter: false,
      ),
      isFalse,
    );
    expect(service.demonBluffRoleIds, hasLength(3));

    await service.toggleDemonBluff(
      'librarian',
      isEligible: true,
      isGameCharacter: false,
    );
    expect(service.demonBluffRoleIds, orderedEquals(['washerwoman', 'chef']));
  });

  test('three bluffs are required at seven regular players, not six', () async {
    final service = await createService();

    expect(service.requiredDemonBluffCount(6), 0);
    expect(service.hasRequiredDemonBluffs(6), isTrue);
    expect(service.requiredDemonBluffCount(7), 3);
    expect(service.hasRequiredDemonBluffs(7), isFalse);

    await service.setDemonBluffRoleIds(['washerwoman', 'librarian', 'chef']);
    expect(service.hasRequiredDemonBluffs(7), isTrue);
    await service.endGame();
    expect(service.demonBluffRoleIds, isEmpty);
  });

  testWidgets(
      'selection/info toggle highlights its actual mode and long press marks only good roles',
      (tester) async {
    final gameState = await createService();
    final characterService = CharacterService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: gameState),
          ChangeNotifierProvider.value(value: characterService),
          ChangeNotifierProvider(create: (_) => SettingsService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SelectCharacterComponent(
              charactersToChooseFrom: [
                character('washerwoman', Fraction.townsfolk),
                character('poisoner', Fraction.minion),
              ],
              onConfirm: () {},
              title: 'Selection',
              confirmButtonText: 'Next',
              isForSetupGame: true,
              demonBluffsEnabled: true,
              needToConfirm: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons).first);
    expect(toggle.isSelected, orderedEquals([false, true]));

    await tester.longPress(find.byType(CharacterAvatar).first);
    await tester.pump();
    expect(gameState.demonBluffRoleIds, orderedEquals(['washerwoman']));
    expect(characterService.gameCharacters, isEmpty,
        reason: 'Long press must not also select the role for the game.');

    await tester.tap(find.byType(CharacterAvatar).first);
    await tester.pump();
    expect(characterService.gameCharacters, isEmpty,
        reason: 'A red token cannot become a game character directly.');

    await tester.tap(find.byIcon(Icons.help).first);
    await tester.pump();
    toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons).first);
    expect(toggle.isSelected, orderedEquals([true, false]));

    await tester.longPress(find.byType(CharacterAvatar).at(1));
    await tester.pump();
    expect(gameState.demonBluffRoleIds, orderedEquals(['washerwoman']),
        reason: 'Information mode must not change bluff selection.');
  });

  testWidgets(
      'missing bluffs keep the disabled continuation action in its warning dialog',
      (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              NextScreenFooter(
                currentScreenName: 'Selection',
                nextScreenName: 'Show characters',
                nextScreenIcon: Icons.remove_red_eye,
                disabled: true,
                blockNavigationWhenDisabled: true,
                validationMessages: const [
                  'Only 1 of 3 required Demon Bluffs has been selected.',
                ],
                onTap: () => continued = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove_red_eye));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
          'Only 1 of 3 required Demon Bluffs has been selected.'),
      findsOneWidget,
    );
    expect(find.text('Yes, continue'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(continued, isFalse);
  });
}
