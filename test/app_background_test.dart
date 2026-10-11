import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the correct artwork for each screen type', () {
    expect(
      AppBackground.assetFor(AppBackgroundType.ui),
      'assets/images/backgrounds/background_grim_ui.png',
    );
    expect(
      AppBackground.assetFor(AppBackgroundType.playground),
      'assets/images/backgrounds/background_grim_playground.png',
    );
  });

  testWidgets('renders one cover-fitted fullscreen background', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppBackground(child: SizedBox.expand()),
      ),
    );

    final background = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = background.decoration as BoxDecoration;
    expect(decoration.image?.fit, BoxFit.cover);
    expect(decoration.image?.alignment, Alignment.topCenter);
    expect(
      (decoration.image?.image as AssetImage).assetName,
      'assets/images/backgrounds/background_grim_ui.png',
    );
  });
}
