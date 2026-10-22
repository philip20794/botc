import 'package:blood_on_the_clocktower/components/layout_diagnostics_panel.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows layout values and physical and logical screen sizes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService();
    await settings.initialized;
    addTearDown(settings.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => LayoutDiagnosticsPanel(
                settings: context.watch<SettingsService>(),
                previewCharacterCount: 12,
              ),
            ),
          ),
        ),
      ),
    );

    final diagnostics = find.byKey(
      const ValueKey('layout-settings-diagnostics-text'),
    );
    String snapshot() => tester.widget<SelectableText>(diagnostics).data!;

    expect(snapshot(), contains('viewportLogical=360.0 x 800.0 dp'));
    expect(snapshot(), contains('viewPhysical=1080 x 2400 px'));
    expect(snapshot(), contains('devicePixelRatio=3.00'));
    expect(snapshot(), contains('viewportWidthClass=compact'));
    expect(snapshot(), contains('numberOfCharacters=12'));
    expect(snapshot(), contains('selectedReminderTokenSize=48.0'));
    expect(snapshot(), contains('unselectedReminderTokenSize=24.0'));
    expect(snapshot(), contains('offsetY=-125.0'));
    expect(snapshot(), contains('platform='));

    await settings.setRadiusX(32.5, persist: false);
    await settings.setTokenOffsetY(-10, persist: false);
    await tester.pump();

    expect(snapshot(), contains('radiusX=32.5'));
    expect(snapshot(), contains('tokenOffsetY=-10.0'));

    tester.view.physicalSize = const Size(2100, 2400);
    await tester.pump();
    expect(snapshot(), contains('viewportLogical=700.0 x 800.0 dp'));
    expect(snapshot(), contains('viewportWidthClass=medium'));
  });
}
