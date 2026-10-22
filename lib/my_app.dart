import 'dart:async';

import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/screens/home_screen.dart';
import 'package:blood_on_the_clocktower/screens/spielbereich_screen.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _backgroundColor = GrimoireColors.background;
  static const _systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _backgroundColor,
    systemNavigationBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    final locale =
        context.select<LanguageService, Locale>((service) => service.locale);
    final gameIsRunning = context
        .select<GameStateService, bool>((service) => service.nightCount > -1);
    final theme = GrimoireTheme.build();

    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      title: 'Blood on the Clocktower',
      locale: locale,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemUiOverlayStyle,
        child: ColoredBox(
          color: _backgroundColor,
          child: _LayoutViewportObserver(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      theme: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          systemOverlayStyle: _systemUiOverlayStyle,
        ),
      ),
      supportedLocales: const [
        Locale('en', ''),
        Locale('de', ''),
      ],
      home: _LaunchSplash(
        child: SafeArea(
          child: gameIsRunning
              ? Theme(
                  data: GrimoireTheme.playground(),
                  child: SpielbereichScreen(),
                )
              : HomeScreen(),
        ),
      ),
    );
  }
}

/// Keeps the full artwork visible after Android has handed control to Flutter.
/// Android 12+ only permits a centered system splash icon, so the native splash
/// cannot display a full-screen portrait image on its own.
class _LaunchSplash extends StatefulWidget {
  const _LaunchSplash({required this.child});

  final Widget child;

  @override
  State<_LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<_LaunchSplash> {
  var _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;
    return const ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/app/splash_screen.png'),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// Listens to MediaQuery changes without notifying Provider during build.
/// The responsive values are applied after the frame, before the splash ends.
class _LayoutViewportObserver extends StatefulWidget {
  const _LayoutViewportObserver({required this.child});

  final Widget child;

  @override
  State<_LayoutViewportObserver> createState() =>
      _LayoutViewportObserverState();
}

class _LayoutViewportObserverState extends State<_LayoutViewportObserver> {
  Size? _lastViewport;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.sizeOf(context);
    if (_lastViewport == viewport) return;
    _lastViewport = viewport;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsService>().updateViewportSize(viewport);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
