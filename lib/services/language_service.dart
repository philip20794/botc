import 'dart:async';

import 'package:blood_on_the_clocktower/models/l10n.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _loading = true;
  final String storageKey = 'locale';
  final String onBoardingKey = 'onBoarding';

  LanguageService() {
    _init();
  }

  void _init() async {
    await _loadLocale();
    _loading = false;
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localeCode = prefs.getString(storageKey);
    if (localeCode != null) {
      _locale = Locale(localeCode);
      notifyListeners();
    }
  }

  Future<void> _saveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, _locale.languageCode);
  }

  Locale get locale => _locale;
  bool get loading => _loading;

  void setLocale(Locale locale) {
    if (!L10n.all.contains(locale)) return; // Check if the locale is supported
    _locale = locale;
    _saveLocale();
    notifyListeners();
  }

  void clearLocale() {
    _locale = const Locale('en'); // Default to English if clearing
    notifyListeners();
  }
}
