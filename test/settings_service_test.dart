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
}
