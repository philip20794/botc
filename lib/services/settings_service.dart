import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  double _characterKnobSize = 90;
  double _tokenKnobSize = 35;
  double _radiusX = 5;
  double _radiusY = 30;
  double _startAngleDiv = 3;
  double _offsetX = -45;
  double _offsetY = -125;
  double _tokenOffsetY = 30;
  double _tokenOffsetX = 45;
  final String _settingsCharacterKnobSizeKey = 'characterKnobSize';
  final String _settingsTokenKnobSizeKey = 'tokenKnobSize';
  final String _settingsRadiusXKey = 'radiusX';
  final String _settingsRadiusYKey = 'radiusY';
  final String _settingsStartAngleDivKey = 'startAngleDiv';
  final String _settingsOffsetXKey = 'offsetX';
  final String _settingsOffsetYKey = 'offsetY';
  final String _settingsTokenOffsetYKey = 'tokenOffsetY';
  final String _settingsTokenOffsetXKey = 'tokenOffsetX';
  bool hideDescription = true;
  bool hideHotToRun = true;
  bool hideTipsAndTricks = true;
  bool hideBluffs = true;
  bool hideTravellers = true;
  bool hideFabled = true;

  double get characterKnobSize => _characterKnobSize;
  double get tokenKnobSize => _tokenKnobSize;
  double get radiusX => _radiusX;
  double get radiusY => _radiusY;
  double get startAngleDiv => _startAngleDiv;
  double get offsetX => _offsetX;
  double get offsetY => _offsetY;
  double get tokenOffsetY => _tokenOffsetY;
  double get tokenOffsetX => _tokenOffsetX;

  SettingsService() {
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _characterKnobSize =
        prefs.getDouble(_settingsCharacterKnobSizeKey) ?? _characterKnobSize;
    _tokenKnobSize =
        prefs.getDouble(_settingsTokenKnobSizeKey) ?? _tokenKnobSize;
    _radiusX = prefs.getDouble(_settingsRadiusXKey) ?? _radiusX;
    _radiusY = prefs.getDouble(_settingsRadiusYKey) ?? _radiusY;
    _startAngleDiv =
        prefs.getDouble(_settingsStartAngleDivKey) ?? _startAngleDiv;
    _offsetX = prefs.getDouble(_settingsOffsetXKey) ?? _offsetX;
    _offsetY = prefs.getDouble(_settingsOffsetYKey) ?? _offsetY;
    _tokenOffsetY = prefs.getDouble(_settingsTokenOffsetYKey) ?? _tokenOffsetY;
    _tokenOffsetX = prefs.getDouble(_settingsTokenOffsetXKey) ?? _tokenOffsetX;
    notifyListeners();
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsCharacterKnobSizeKey, _characterKnobSize);
    prefs.setDouble(_settingsTokenKnobSizeKey, _tokenKnobSize);
    prefs.setDouble(_settingsRadiusXKey, _radiusX);
    prefs.setDouble(_settingsRadiusYKey, _radiusY);
    prefs.setDouble(_settingsStartAngleDivKey, _startAngleDiv);
    prefs.setDouble(_settingsOffsetXKey, _offsetX);
    prefs.setDouble(_settingsOffsetYKey, _offsetY);
    prefs.setDouble(_settingsTokenOffsetYKey, _tokenOffsetY);
    prefs.setDouble(_settingsTokenOffsetXKey, _tokenOffsetX);
  }

  Future<void> setCharacterKnobSize(double value) async {
    _characterKnobSize = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsCharacterKnobSizeKey, _characterKnobSize);
    notifyListeners();
  }

  Future<void> setTokenKnobSize(double value) async {
    _tokenKnobSize = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsTokenKnobSizeKey, _tokenKnobSize);
    notifyListeners();
  }

  Future<void> setRadiusX(double value) async {
    _radiusX = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsRadiusXKey, _radiusX);
    notifyListeners();
  }

  Future<void> setRadiusY(double value) async {
    _radiusY = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsRadiusYKey, _radiusY);
    notifyListeners();
  }

  Future<void> setStartAngleDiv(double value) async {
    _startAngleDiv = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsStartAngleDivKey, _startAngleDiv);
    notifyListeners();
  }

  Future<void> setOffsetX(double value) async {
    _offsetX = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsOffsetXKey, _offsetX);
    notifyListeners();
  }

  Future<void> setOffsetY(double value) async {
    _offsetY = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsOffsetYKey, _offsetY);
    notifyListeners();
  }

  Future<void> setTokenOffsetY(double value) async {
    _tokenOffsetY = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsTokenOffsetYKey, _tokenOffsetY);
    notifyListeners();
  }

  Future<void> setTokenOffsetX(double value) async {
    _tokenOffsetX = value;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_settingsTokenOffsetXKey, _tokenOffsetX);
    notifyListeners();
  }

  void resetSettings() {
    _characterKnobSize = 100;
    _tokenKnobSize = 50;
    _radiusX = 0.35;
    _radiusY = 0.38;
    _startAngleDiv = 4;
    _offsetX = 80;
    _offsetY = 90;
    _saveSettings();
    notifyListeners();
  }
}
