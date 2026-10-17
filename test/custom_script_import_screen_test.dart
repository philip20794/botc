import 'dart:convert';

import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/custom_script_import_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPreferences.getInstance();
  });

  testWidgets('uses the Grimoire theme for custom script import',
      (tester) async {
    final scripts = ScriptService();
    await scripts.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: scripts),
          ChangeNotifierProvider(create: (_) => CharacterService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomScriptImportScreen(),
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    expect(theme.scaffoldBackgroundColor, GrimoireColors.background);
    expect(theme.brightness, Brightness.dark);
    expect(theme.cardTheme.color, isNotNull);
    expect(theme.dialogTheme.backgroundColor, GrimoireColors.surface);
  });

  testWidgets('imports selected and pasted JSON and preserves invalid input',
      (tester) async {
    await _pumpImportScreen(
      tester,
      pickJson: () async => _scriptJson('File import'),
    );

    await tester.tap(find.byKey(const ValueKey('scriptImportPickFile')));
    await _waitForImportAnalysis(tester);
    await _scrollToImportOutput(tester);

    expect(find.text('File import'), findsOneWidget);
    expect(find.byKey(const ValueKey('scriptImportPreview')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    final textField = find.byKey(const ValueKey('scriptImportPasteJson'));

    await tester.enterText(textField, _scriptJson('Pasted import'));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
              find.byKey(const ValueKey('scriptImportAnalyzeText')))
          .onPressed,
      isNotNull,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('scriptImportAnalyzeText')),
    );
    await tester.tap(find.byKey(const ValueKey('scriptImportAnalyzeText')));
    await _waitForImportAnalysis(tester);
    await _scrollToImportOutput(tester);

    expect(find.text('Pasted import', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey('scriptImportPreview')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(textField).controller!.text,
      _scriptJson('Pasted import'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.enterText(textField, '{ not valid JSON');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('scriptImportAnalyzeText')),
    );
    await tester.tap(find.byKey(const ValueKey('scriptImportAnalyzeText')));
    await _waitForImportAnalysis(tester);
    await _scrollToImportOutput(tester);

    expect(
      find.text('The selected file is not valid JSON.', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('scriptImportPreview')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(textField).controller!.text,
      '{ not valid JSON',
    );
  });

  testWidgets('requires a name before saving a nameless script',
      (tester) async {
    final scripts = await _pumpImportScreen(
      tester,
      pickJson: () async => jsonEncode([
        {'id': '_meta'},
        'imp',
      ]),
    );

    await tester.tap(find.byKey(const ValueKey('scriptImportPickFile')));
    await _waitForImportAnalysis(tester);

    final nameField = find.byKey(const ValueKey('scriptImportName'));
    final confirm = find.byKey(const ValueKey('scriptImportConfirm'));
    expect(tester.widget<TextField>(nameField).controller!.text, isEmpty);
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.enterText(nameField, '   ');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.enterText(nameField, '  New name  ');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(scripts.customScripts.single.name, 'New name');
  });

  testWidgets('prefills the imported name and saves an edited one',
      (tester) async {
    final scripts = await _pumpImportScreen(
      tester,
      pickJson: () async => _scriptJson('Original name'),
    );

    await tester.tap(find.byKey(const ValueKey('scriptImportPickFile')));
    await _waitForImportAnalysis(tester);
    final nameField = find.byKey(const ValueKey('scriptImportName'));
    final confirm = find.byKey(const ValueKey('scriptImportConfirm'));
    expect(tester.widget<TextField>(nameField).controller!.text, 'Original name');
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNotNull);

    await tester.enterText(nameField, 'Changed name');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(scripts.customScripts.single.name, 'Changed name');
  });

  testWidgets('disables text analysis for empty or whitespace-only input',
      (tester) async {
    await _pumpImportScreen(tester);
    final analyzeButton = find.byKey(const ValueKey('scriptImportAnalyzeText'));

    expect(tester.widget<ElevatedButton>(analyzeButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('scriptImportPasteJson')),
      '   ',
    );
    await tester.pump();

    expect(tester.widget<ElevatedButton>(analyzeButton).onPressed, isNull);
  });

  testWidgets('opens the Script Tool externally without clearing pasted JSON',
      (tester) async {
    Uri? openedUri;
    await _pumpImportScreen(
      tester,
      openUri: (uri) async {
        openedUri = uri;
        return true;
      },
    );
    final textField = find.byKey(const ValueKey('scriptImportPasteJson'));
    await tester.enterText(textField, _scriptJson('Keep this text'));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final openTool = find.byKey(const ValueKey('scriptImportOpenTool'));
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(openTool);
    await tester.pump();

    expect(openedUri, Uri.parse('https://script.bloodontheclocktower.com/'));
    expect(
      tester.widget<TextField>(textField).controller!.text,
      _scriptJson('Keep this text'),
    );
  });
}

Future<ScriptService> _pumpImportScreen(
  WidgetTester tester, {
  Future<String?> Function()? pickJson,
  Future<bool> Function(Uri uri)? openUri,
}) async {
  final scripts = ScriptService();
  await scripts.ready;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: scripts),
        ChangeNotifierProvider(create: (_) => CharacterService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomScriptImportScreen(pickJson: pickJson, openUri: openUri),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return scripts;
}

String _scriptJson(String name) => jsonEncode([
      {'id': '_meta', 'name': name},
      'imp',
    ]);

Future<void> _waitForImportAnalysis(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(seconds: 1)),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToImportOutput(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();
}
