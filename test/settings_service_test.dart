import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists a layout slider value once when the interaction ends',
      () async {
    SharedPreferences.setMockInitialValues({'characterKnobSize': 90.0});
    final settings = SettingsService();
    await settings.initialized;

    await settings.setCharacterKnobSize(120, persist: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('characterKnobSize'), 90.0);

    await settings.saveSettings();
    expect(prefs.getDouble('characterKnobSize'), 120.0);
  });

  test('every layout setter notifies immediately and keeps deferred storage',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService();
    await settings.initialized;
    var notifications = 0;
    settings.addListener(() => notifications++);

    await settings.setCharacterKnobSize(100, persist: false);
    await settings.setTokenKnobSize(40, persist: false);
    await settings.setRadiusX(15, persist: false);
    await settings.setRadiusY(45, persist: false);
    await settings.setStartAngleDiv(4, persist: false);
    await settings.setOffsetX(-20, persist: false);
    await settings.setOffsetY(-100, persist: false);
    await settings.setTokenOffsetX(30, persist: false);
    await settings.setTokenOffsetY(20, persist: false);

    expect(notifications, 9);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('offsetX'), isFalse);

    await settings.saveSettings();
    expect(prefs.getDouble('offsetX'), -20);
    expect(prefs.getDouble('tokenOffsetY'), 20);
  });

  test('changed layout positions notify their consumers immediately', () {
    final characters = CharacterService();
    var notifications = 0;
    characters.addListener(() => notifications++);

    characters.setCharacterPositions(const {0: Offset(10, 20)});
    expect(notifications, 1);

    characters.setCharacterPositions(const {0: Offset(10, 20)});
    expect(notifications, 1,
        reason: 'Identical positions should not cause a rebuild.');

    characters.setCharacterPosition(0, const Offset(15, 25));
    expect(notifications, 2);
  });
}
