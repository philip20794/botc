import 'package:blood_on_the_clocktower/components/script_complexity_summary.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('complexity summary fits two ratings in a narrow selector',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: scripts,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 160, child: ScriptComplexitySummary()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('1.5/5'), findsNWidgets(2));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('storytellerComplexityBadge')))
          .height,
      24,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('playerComplexityBadge')))
          .height,
      24,
    );
    expect(tester.takeException(), isNull);
  });
}
