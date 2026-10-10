import 'package:blood_on_the_clocktower/services/auth_service.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'my_app.dart';
import 'services/language_service.dart';

void main() async {
  // Sperre die App auf Portrait-Modus
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    systemNavigationBarDividerColor: Color(0xFF040004),
    systemNavigationBarColor: Color(0xFF040004),
    statusBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => LanguageService()),
          ChangeNotifierProvider(create: (context) => CharacterService()),
          ChangeNotifierProvider(create: (context) => GameStateService()),
          ChangeNotifierProvider(create: (context) => RoleNotesService()),
          ChangeNotifierProvider(create: (context) => SettingsService()),
          ChangeNotifierProvider(create: (context) => AuthService())
        ],
        child: const MyApp(),
      ),
    );
  });
}
