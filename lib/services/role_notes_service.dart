import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleNotesService extends ChangeNotifier {
  final String _storagePlayerPositionsKey = 'role_notes_player_positions';
  final String _storagePlayerRolesKey = 'role_notes_player_roles';
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  final Map<String, Offset> _playerPositions = {};
  final Map<String, List<String>> _playerRoleImages = {};

  RoleNotesService() {
    init();
  }

  Future<void> init() async {
    final prefs = await _prefs;
    _loadPlayerPositions(prefs);
    _loadPlayerRoles(prefs);
    notifyListeners();
  }

  Offset? positionOf(String playerName) => _playerPositions[playerName];

  List<String> roleImagesFor(String playerName) =>
      List.unmodifiable(_playerRoleImages[playerName] ?? const []);

  Map<String, List<String>> get playerRoleImages => _playerRoleImages;

  bool hasAnyRoleNotes() {
    return _playerRoleImages.values.any((roles) => roles.isNotEmpty);
  }

  bool needsPositionSync(
      List<String> playerNames, Size boardSize, double playerTokenSize) {
    final playerNameSet = playerNames.toSet();
    if (_playerPositions.keys.any((name) => !playerNameSet.contains(name))) {
      return true;
    }
    if (_playerRoleImages.keys.any((name) => !playerNameSet.contains(name))) {
      return true;
    }
    for (final playerName in playerNames) {
      final position = _playerPositions[playerName];
      if (position == null) {
        return true;
      }
      if (position.dx < 0 ||
          position.dy < 0 ||
          position.dx > max(0, boardSize.width - playerTokenSize) ||
          position.dy > max(0, boardSize.height - playerTokenSize)) {
        return true;
      }
    }
    return false;
  }

  Future<void> ensureDefaultPositions(
      List<String> playerNames, Size boardSize, double playerTokenSize,
      {bool force = false}) async {
    if (boardSize.width <= 0 || boardSize.height <= 0 || playerNames.isEmpty) {
      return;
    }

    final playerNameSet = playerNames.toSet();
    var positionsChanged = false;
    var rolesChanged = false;

    _playerPositions.removeWhere((playerName, position) {
      final shouldRemove = !playerNameSet.contains(playerName);
      positionsChanged = positionsChanged || shouldRemove;
      return shouldRemove;
    });

    _playerRoleImages.removeWhere((playerName, roles) {
      final shouldRemove = !playerNameSet.contains(playerName);
      rolesChanged = rolesChanged || shouldRemove;
      return shouldRemove;
    });

    final radius = max(
      0.0,
      min(boardSize.width, boardSize.height) * 0.36 - playerTokenSize * 0.5,
    );
    final center = Offset(
      (boardSize.width - playerTokenSize) / 2,
      (boardSize.height - playerTokenSize) / 2,
    );

    for (var i = 0; i < playerNames.length; i++) {
      final playerName = playerNames[i];
      if (!force && _playerPositions.containsKey(playerName)) {
        continue;
      }
      final angle = -pi / 2 + (2 * pi * i / playerNames.length);
      final nextPosition = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      _playerPositions[playerName] =
          clampPlayerPosition(nextPosition, boardSize, playerTokenSize);
      positionsChanged = true;
    }

    if (positionsChanged) {
      await _savePlayerPositions();
    }
    if (rolesChanged) {
      await _savePlayerRoles();
    }
    if (positionsChanged || rolesChanged) {
      notifyListeners();
    }
  }

  Future<void> resetPositions(
      List<String> playerNames, Size boardSize, double playerTokenSize) {
    return ensureDefaultPositions(playerNames, boardSize, playerTokenSize,
        force: true);
  }

  Future<void> setPlayerPosition(String playerName, Offset position,
      Size boardSize, double playerTokenSize) async {
    final clampedPosition =
        clampPlayerPosition(position, boardSize, playerTokenSize);
    if (_playerPositions[playerName] == clampedPosition) {
      return;
    }
    _playerPositions[playerName] = clampedPosition;
    await _savePlayerPositions();
    notifyListeners();
  }

  void updatePlayerPosition(String playerName, Offset position, Size boardSize,
      double playerTokenSize) {
    final clampedPosition =
        clampPlayerPosition(position, boardSize, playerTokenSize);
    if (_playerPositions[playerName] == clampedPosition) {
      return;
    }
    _playerPositions[playerName] = clampedPosition;
    notifyListeners();
  }

  Future<void> savePlayerPositions() {
    return _savePlayerPositions();
  }

  Future<void> setRolesForPlayer(
      String playerName, List<String> roleImages) async {
    final uniqueRoleImages = <String>[];
    for (final roleImage in roleImages) {
      if (!uniqueRoleImages.contains(roleImage) &&
          uniqueRoleImages.length < 4) {
        uniqueRoleImages.add(roleImage);
      }
    }

    if (uniqueRoleImages.isEmpty) {
      if (!_playerRoleImages.containsKey(playerName)) {
        return;
      }
      _playerRoleImages.remove(playerName);
    } else {
      final existingRoleImages = _playerRoleImages[playerName];
      if (existingRoleImages != null &&
          _sameRoleImages(existingRoleImages, uniqueRoleImages)) {
        return;
      }
      _playerRoleImages[playerName] = uniqueRoleImages;
    }

    await _savePlayerRoles();
    notifyListeners();
  }

  Future<void> removeRoleFromPlayer(String playerName, String roleImage) async {
    final roles = List<String>.from(_playerRoleImages[playerName] ?? const []);
    if (!roles.contains(roleImage)) {
      return;
    }
    roles.remove(roleImage);
    await setRolesForPlayer(playerName, roles);
  }

  Future<void> clearRolesForPlayer(String playerName) async {
    if (!_playerRoleImages.containsKey(playerName)) {
      return;
    }
    _playerRoleImages.remove(playerName);
    await _savePlayerRoles();
    notifyListeners();
  }

  Future<void> clearAllRoleNotes() async {
    if (!hasAnyRoleNotes()) {
      return;
    }
    _playerRoleImages.clear();
    await _savePlayerRoles();
    notifyListeners();
  }

  Map<String, List<String>> duplicateRoleImages() {
    final rolePlayers = <String, List<String>>{};
    _playerRoleImages.forEach((playerName, roles) {
      for (final roleImage in roles) {
        rolePlayers.putIfAbsent(roleImage, () => []).add(playerName);
      }
    });
    rolePlayers.removeWhere((roleImage, playerNames) => playerNames.length < 2);
    return rolePlayers;
  }

  Offset clampPlayerPosition(
      Offset position, Size boardSize, double playerTokenSize) {
    return Offset(
      position.dx
          .clamp(0.0, max(0.0, boardSize.width - playerTokenSize))
          .toDouble(),
      position.dy
          .clamp(0.0, max(0.0, boardSize.height - playerTokenSize))
          .toDouble(),
    );
  }

  void _loadPlayerPositions(SharedPreferences prefs) {
    final playerPositionsJson = prefs.getString(_storagePlayerPositionsKey);
    if (playerPositionsJson == null) {
      return;
    }

    final playerPositionsMap =
        jsonDecode(playerPositionsJson) as Map<String, dynamic>;
    _playerPositions.clear();
    playerPositionsMap.forEach((playerName, value) {
      final positionMap = value as Map<String, dynamic>;
      _playerPositions[playerName] = Offset(
        (positionMap['dx'] as num).toDouble(),
        (positionMap['dy'] as num).toDouble(),
      );
    });
  }

  void _loadPlayerRoles(SharedPreferences prefs) {
    final playerRolesJson = prefs.getString(_storagePlayerRolesKey);
    if (playerRolesJson == null) {
      return;
    }

    final playerRolesMap = jsonDecode(playerRolesJson) as Map<String, dynamic>;
    _playerRoleImages.clear();
    playerRolesMap.forEach((playerName, value) {
      final roles = value as List<dynamic>;
      _playerRoleImages[playerName] =
          roles.map((roleImage) => roleImage.toString()).toList();
    });
  }

  Future<void> _savePlayerPositions() async {
    final prefs = await _prefs;
    final playerPositionsMap = <String, dynamic>{};
    _playerPositions.forEach((playerName, position) {
      playerPositionsMap[playerName] = {
        'dx': position.dx,
        'dy': position.dy,
      };
    });
    await prefs.setString(
      _storagePlayerPositionsKey,
      jsonEncode(playerPositionsMap),
    );
  }

  Future<void> _savePlayerRoles() async {
    final prefs = await _prefs;
    await prefs.setString(
        _storagePlayerRolesKey, jsonEncode(_playerRoleImages));
  }

  bool _sameRoleImages(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
