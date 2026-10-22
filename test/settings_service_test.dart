import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  test('a new installation uses the calibrated viewport defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService(
      initialViewport: const Size(360, 708),
    );
    await settings.initialized;
    expect(settings.characterKnobSize, closeTo(79.74238389840153, 0.0001));
    expect(settings.radiusX, closeTo(27.347180606397387, 0.0001));
    expect(settings.radiusY, closeTo(48.80186513889054, 0.0001));
    expect(settings.startAngleDiv, closeTo(3.834969935972998, 0.0001));
    expect(settings.offsetX, closeTo(-19.35562976298884, 0.0001));
    expect(settings.offsetY, closeTo(-26.276387173705302, 0.0001));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('characterKnobSize'), isFalse);
    expect(prefs.containsKey('layoutUsesResponsiveDefaults'), isFalse);

    settings.updateViewportSize(const Size(393, 852));
    final larger = ResponsiveLayoutDefaults.forViewport(const Size(393, 852));
    expect(settings.characterKnobSize, closeTo(larger.characterKnobSize, 0.001));
    expect(settings.radiusY, closeTo(larger.radiusY, 0.001));
  });

  test('manual settings persist across resize and reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService(
      initialViewport: const Size(360, 708),
    );
    await settings.initialized;
    await settings.setRadiusX(55, persist: false);
    settings.updateViewportSize(const Size(430, 932));
    expect(settings.radiusX, 55);

    await settings.saveSettings();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('layoutUsesResponsiveDefaults'), isFalse);

    final restored = SettingsService(
      initialViewport: const Size(320, 640),
    );
    await restored.initialized;
    expect(restored.radiusX, 55);
    expect(restored.characterKnobSize, closeTo(79.74238389840153, 0.001));
    restored.updateViewportSize(const Size(393, 852));
    expect(restored.radiusX, 55);
  });

  test('reset discards manual layout and resumes viewport defaults', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'characterKnobSize': 112.0,
      'radiusX': 70.0,
      'layoutUsesResponsiveDefaults': false,
    });
    final settings = SettingsService(
      initialViewport: const Size(393, 852),
    );
    await settings.initialized;
    expect(settings.characterKnobSize, 112);
    expect(settings.radiusX, 70);

    await settings.resetSettings();
    final defaults = ResponsiveLayoutDefaults.forViewport(const Size(393, 852));
    expect(settings.characterKnobSize, closeTo(defaults.characterKnobSize, 0.001));
    expect(settings.radiusX, closeTo(defaults.radiusX, 0.001));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('layoutUsesResponsiveDefaults'), isTrue);
    expect(prefs.containsKey('characterKnobSize'), isFalse);
    expect(prefs.containsKey('radiusX'), isFalse);

    settings.updateViewportSize(const Size(320, 640));
    expect(
      settings.characterKnobSize,
      closeTo(
        ResponsiveLayoutDefaults.forViewport(const Size(320, 640))
            .characterKnobSize,
        0.001,
      ),
    );

    final restored = SettingsService(
      initialViewport: const Size(430, 932),
    );
    await restored.initialized;
    expect(
      restored.characterKnobSize,
      closeTo(
        ResponsiveLayoutDefaults.forViewport(const Size(430, 932))
            .characterKnobSize,
        0.001,
      ),
    );
  });

  test('legacy persisted settings are treated as manual', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'characterKnobSize': 99.0,
      'offsetY': -45.0,
    });
    final settings = SettingsService(
      initialViewport: const Size(360, 708),
    );
    await settings.initialized;
    settings.updateViewportSize(const Size(430, 932));
    expect(settings.characterKnobSize, 99);
    expect(settings.offsetY, -45);
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
