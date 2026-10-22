import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
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
  double _selectedReminderTokenSize = 48;
  double _unselectedReminderTokenSize = 24;
  final String _settingsCharacterKnobSizeKey = 'characterKnobSize';
  final String _settingsTokenKnobSizeKey = 'tokenKnobSize';
  final String _settingsRadiusXKey = 'radiusX';
  final String _settingsRadiusYKey = 'radiusY';
  final String _settingsStartAngleDivKey = 'startAngleDiv';
  final String _settingsOffsetXKey = 'offsetX';
  final String _settingsOffsetYKey = 'offsetY';
  final String _settingsTokenOffsetYKey = 'tokenOffsetY';
  final String _settingsTokenOffsetXKey = 'tokenOffsetX';
  final String _settingsSelectedReminderTokenSizeKey =
      'selectedReminderTokenSize';
  final String _settingsUnselectedReminderTokenSizeKey =
      'unselectedReminderTokenSize';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  static const _automaticDefaultsKey = 'layoutUsesResponsiveDefaults';
  Size _viewport;
  bool _usesResponsiveDefaults = true;
  bool _settingsLoaded = false;
  late final Future<void> initialized;
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
  double get selectedReminderTokenSize => _selectedReminderTokenSize;
  double get unselectedReminderTokenSize => _unselectedReminderTokenSize;

  SettingsService({
    Size initialViewport = ResponsiveLayoutDefaults.referenceViewport,
  }) : _viewport = initialViewport {
    _applyDefaults(ResponsiveLayoutDefaults.forViewport(initialViewport));
    initialized = _loadSettings();
  }

  List<String> get _layoutKeys => [
        _settingsCharacterKnobSizeKey,
        _settingsTokenKnobSizeKey,
        _settingsRadiusXKey,
        _settingsRadiusYKey,
        _settingsStartAngleDivKey,
        _settingsOffsetXKey,
        _settingsOffsetYKey,
        _settingsTokenOffsetXKey,
        _settingsTokenOffsetYKey,
        _settingsSelectedReminderTokenSizeKey,
        _settingsUnselectedReminderTokenSizeKey,
      ];

  void _applyDefaults(ResponsiveLayoutDefaults defaults) {
    _characterKnobSize = defaults.characterKnobSize;
    _tokenKnobSize = defaults.tokenKnobSize;
    _radiusX = defaults.radiusX;
    _radiusY = defaults.radiusY;
    _startAngleDiv = defaults.startAngleDiv;
    _offsetX = defaults.offsetX;
    _offsetY = defaults.offsetY;
    _tokenOffsetX = defaults.tokenOffsetX;
    _tokenOffsetY = defaults.tokenOffsetY;
    _selectedReminderTokenSize = defaults.selectedReminderTokenSize;
    _unselectedReminderTokenSize = defaults.unselectedReminderTokenSize;
  }

  /// Recalculate only while the user has not customized the layout.
  /// MaterialApp's viewport observer supplies the current logical size.
  void updateViewportSize(Size viewport) {
    if (viewport == _viewport ||
        viewport.width <= 0 ||
        viewport.height <= 0 ||
        !viewport.width.isFinite ||
        !viewport.height.isFinite) {
      return;
    }
    _viewport = viewport;
    if (_settingsLoaded && _usesResponsiveDefaults) {
      _applyDefaults(ResponsiveLayoutDefaults.forViewport(viewport));
      notifyListeners();
    }
  }


  Future<void> _loadSettings() async {
    final prefs = await _prefs;
    // Older versions stored only numeric slider values. Treat them as manual
    // settings, even when the new mode flag does not exist yet.
    _usesResponsiveDefaults = prefs.getBool(_automaticDefaultsKey) ??
        !_layoutKeys.any(prefs.containsKey);
    if (_usesResponsiveDefaults) {
      _applyDefaults(ResponsiveLayoutDefaults.forViewport(_viewport));
    } else {
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
      _selectedReminderTokenSize =
          prefs.getDouble(_settingsSelectedReminderTokenSizeKey) ??
              _selectedReminderTokenSize;
      _unselectedReminderTokenSize =
          prefs.getDouble(_settingsUnselectedReminderTokenSizeKey) ??
              _unselectedReminderTokenSize;
    }
    _settingsLoaded = true;
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await initialized;
    _usesResponsiveDefaults = false;
    final prefs = await _prefs;
    await prefs.setBool(_automaticDefaultsKey, false);
    await Future.wait([
      prefs.setDouble(_settingsCharacterKnobSizeKey, _characterKnobSize),
      prefs.setDouble(_settingsTokenKnobSizeKey, _tokenKnobSize),
      prefs.setDouble(_settingsRadiusXKey, _radiusX),
      prefs.setDouble(_settingsRadiusYKey, _radiusY),
      prefs.setDouble(_settingsStartAngleDivKey, _startAngleDiv),
      prefs.setDouble(_settingsOffsetXKey, _offsetX),
      prefs.setDouble(_settingsOffsetYKey, _offsetY),
      prefs.setDouble(_settingsTokenOffsetYKey, _tokenOffsetY),
      prefs.setDouble(_settingsTokenOffsetXKey, _tokenOffsetX),
      prefs.setDouble(
          _settingsSelectedReminderTokenSizeKey, _selectedReminderTokenSize),
      prefs.setDouble(_settingsUnselectedReminderTokenSizeKey,
          _unselectedReminderTokenSize),
    ]);
  }

  Future<void> setCharacterKnobSize(double value, {bool persist = true}) async {
    if (_characterKnobSize == value) {
      return;
    }
    _characterKnobSize = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsCharacterKnobSizeKey, _characterKnobSize);
    }
    notifyListeners();
  }

  Future<void> setTokenKnobSize(double value, {bool persist = true}) async {
    if (_tokenKnobSize == value) {
      return;
    }
    _tokenKnobSize = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsTokenKnobSizeKey, _tokenKnobSize);
    }
    notifyListeners();
  }

  Future<void> setSelectedReminderTokenSize(
    double value, {
    bool persist = true,
  }) async {
    if (_selectedReminderTokenSize == value) return;
    _selectedReminderTokenSize = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(
        _settingsSelectedReminderTokenSizeKey,
        _selectedReminderTokenSize,
      );
    }
    notifyListeners();
  }

  Future<void> setUnselectedReminderTokenSize(
    double value, {
    bool persist = true,
  }) async {
    if (_unselectedReminderTokenSize == value) return;
    _unselectedReminderTokenSize = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(
        _settingsUnselectedReminderTokenSizeKey,
        _unselectedReminderTokenSize,
      );
    }
    notifyListeners();
  }

  Future<void> setRadiusX(double value, {bool persist = true}) async {
    if (_radiusX == value) {
      return;
    }
    _radiusX = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsRadiusXKey, _radiusX);
    }
    notifyListeners();
  }

  Future<void> setRadiusY(double value, {bool persist = true}) async {
    if (_radiusY == value) {
      return;
    }
    _radiusY = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsRadiusYKey, _radiusY);
    }
    notifyListeners();
  }

  Future<void> setStartAngleDiv(double value, {bool persist = true}) async {
    if (_startAngleDiv == value) {
      return;
    }
    _startAngleDiv = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsStartAngleDivKey, _startAngleDiv);
    }
    notifyListeners();
  }

  Future<void> setOffsetX(double value, {bool persist = true}) async {
    if (_offsetX == value) {
      return;
    }
    _offsetX = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsOffsetXKey, _offsetX);
    }
    notifyListeners();
  }

  Future<void> setOffsetY(double value, {bool persist = true}) async {
    if (_offsetY == value) {
      return;
    }
    _offsetY = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsOffsetYKey, _offsetY);
    }
    notifyListeners();
  }

  Future<void> setTokenOffsetY(double value, {bool persist = true}) async {
    if (_tokenOffsetY == value) {
      return;
    }
    _tokenOffsetY = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsTokenOffsetYKey, _tokenOffsetY);
    }
    notifyListeners();
  }

  Future<void> setTokenOffsetX(double value, {bool persist = true}) async {
    if (_tokenOffsetX == value) {
      return;
    }
    _tokenOffsetX = value;
    _usesResponsiveDefaults = false;
    if (persist) {
      final prefs = await _prefs;
      await prefs.setBool(_automaticDefaultsKey, false);
      await prefs.setDouble(_settingsTokenOffsetXKey, _tokenOffsetX);
    }
    notifyListeners();
  }

  /// Return to viewport-dependent defaults, including after a manual edit.
  /// Deleting old numeric values prevents older saved layouts from resurfacing.
  Future<void> resetSettings() async {
    await initialized;
    _usesResponsiveDefaults = true;
    _applyDefaults(ResponsiveLayoutDefaults.forViewport(_viewport));
    notifyListeners();

    final prefs = await _prefs;
    await prefs.setBool(_automaticDefaultsKey, true);
    await Future.wait(_layoutKeys.map(prefs.remove));
  }
}
