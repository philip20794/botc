import 'package:blood_on_the_clocktower/components/next_screen_footer.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps preparation navigation readable at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: GrimoireTheme.build(),
        home: const Scaffold(
          body: Stack(
            children: const [
              NextScreenFooter(
                currentScreenName: 'Charakterauswahl vorbereiten',
                nextScreenName: 'Rollen zeigen',
                nextScreenIcon: Icons.visibility_outlined,
                disabled: false,
                hideHomeButton: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('Rollen zeigen'));
    expect(label.style?.fontSize, 13);
    expect(tester.takeException(), isNull);
  });
}
