import 'dart:async';

import 'package:blood_on_the_clocktower/firebase_options.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/firestore_game_repository.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'my_app.dart';
import 'services/language_service.dart';

void main() async {
  // Sperre die App auf Portrait-Modus
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: GrimoireColors.background,
    systemNavigationBarDividerColor: GrimoireColors.background,
    systemNavigationBarColor: GrimoireColors.background,
    statusBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final scriptService = ScriptService();
  final nightOrderService = NightOrderService();
  final chronicleService = ChronicleService();
  final gameRecordUploadQueue = GameRecordUploadQueue();
  final firestoreGameRepository = FirestoreGameRepository();

  // Publication is intentionally silent and best-effort. The durable queue
  // keeps reports for a later launch when the device is offline right now.
  gameRecordUploadQueue.addListener(() {
    unawaited(firestoreGameRepository.publishPending(gameRecordUploadQueue));
  });
  unawaited(gameRecordUploadQueue.ready.then(
    (_) => firestoreGameRepository.publishPending(gameRecordUploadQueue),
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LanguageService()),
        ChangeNotifierProvider.value(value: chronicleService),
        ChangeNotifierProvider(
          create: (context) => CharacterService(
            chronicleService: chronicleService,
          ),
        ),
        ChangeNotifierProvider.value(value: scriptService),
        ChangeNotifierProvider.value(value: nightOrderService),
        ChangeNotifierProvider.value(value: gameRecordUploadQueue),
        Provider.value(value: firestoreGameRepository),
        ChangeNotifierProvider(
          create: (context) => GameStateService(
            scriptService: scriptService,
            nightOrderService: nightOrderService,
            chronicleService: chronicleService,
            gameRecordUploadQueue: gameRecordUploadQueue,
          ),
        ),
        ChangeNotifierProvider(create: (context) => RoleNotesService()),
        ChangeNotifierProvider(create: (context) => SettingsService()),
      ],
      child: const MyApp(),
    ),
  );
}
