import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    LanguageService languageService = Provider.of<LanguageService>(context);
    final gameStateService = Provider.of<GameStateService>(context);
    var gameIsRunning = gameStateService.nightCount > -1;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarDividerColor: Color(0xFF040004),
      systemNavigationBarColor: Color(0xFF040004),
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        title: "Blood on the Clocktower",
        locale: languageService.locale,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor:
                const Color(0xFF6f678a), // Hintergrundfarbe der Textfelder
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), // Abgerundete Ecken
              borderSide: const BorderSide(
                color: Color(0xFF4a3b5e), // Farbe des Rahmens mit Transparenz
                width: 2, // Breite des Rahmens
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4a3b5e),
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF4a3b5e),
                width: 2,
              ),
            ),
            labelStyle: const TextStyle(
              color: Colors.white, // Farbe des Labels
            ),
            hintStyle: const TextStyle(
              color: Colors.white, // Farbe des Hinweises
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white), // Textfarbe
          ),
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: Colors.white,
          ),
          radioTheme: RadioThemeData(
            fillColor: MaterialStateProperty.resolveWith<Color>(
                (Set<MaterialState> states) {
              if (states.contains(MaterialState.selected)) {
                return const Color(
                    0xFF4a3b5e); // Farbe für ausgewählten Zustand
              }
              return const Color(
                  0xFF4a3b5e); // Farbe für nicht ausgewählten Zustand (Außenring)
            }),
            overlayColor: MaterialStateProperty.all(Colors.transparent),
          ),
        ),
        supportedLocales: const [
          Locale('en', ''),
          Locale('de', ''),
        ],
        home: SafeArea(
            child: gameIsRunning ? SpielbereichScreen() : HomeScreen()));
  }
}
