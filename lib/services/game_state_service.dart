import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/quick_flow_interpreter.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameStateService extends ChangeNotifier {
  static const _quickFlowInterpreter = QuickFlowInterpreter();
  final ScriptService _scriptService;
  final NightOrderService _nightOrderService;
  late final Future<void> ready;
  bool _isLocked = false;
  bool _forceUpdateLayout = false;
  final String _storageIsLockedKey = 'is_locked';
  Map<String, List<Token>> _characterTokens = {};
  Map<String, bool> _characterAliveState = {};
  List<Token> unsedGameTokens = [];
  List<String> playerNames = [];
  int _nightCount = -1;
  bool initIsDone = false;
  bool _chracterSelectionDone = false;
  double _nightStateNumber = 0;
  String? _currentNightStepId;
  double? _legacyNightStateNumber;
  bool charactersWhereShownToPlayers = false;
  final String _storageCharacterTokensKey = 'character_tokens';
  final String _storageCharacterAliveStateKey = 'character_alive_state';
  final String _storagePlayerNamesKey = 'player_names';
  final String _storageGamesetKey = 'gameset';
  final String _storageNightCountKey = 'night_count';
  final String _storageNightStateNumberKey = 'night_state_number';
  static const String _storageNightStepIdKey = 'night_step_id';
  final String _storageShowCharactersToPlayersKey =
      'show_characters_to_players';
  final String _chracterSelectionDoneKey = 'character_selection_done';
  static const String _storageDemonBluffRoleIdsKey = 'demon_bluff_role_ids';
  static const String _storageQuickFlowStateKey = 'quick_flow_state';
  List<String> _demonBluffRoleIds = [];
  final Map<String, String> _quickFlowCharacterSelections = {};
  final Map<String, List<String>> _quickFlowStepTargets = {};
  final Set<String> _quickFlowManualOverrides = {};
  final Set<String> _quickFlowConfirmedInfo = {};
  final Map<String, _QuickFlowNightBaseline> _quickFlowNightBaselines = {};
  String? _activeQuickFlowContextKey;
  String? _activeQuickFlowStepKey;
  int? _openMenuId;
  String? openTokenMenuId;

  GameStateService({
    ScriptService? scriptService,
    NightOrderService? nightOrderService,
  })  : _scriptService = scriptService ?? ScriptService(),
        _nightOrderService = nightOrderService ?? NightOrderService() {
    _scriptService.addListener(_onScriptSelectionChanged);
    ready = init();
  }

  void _onScriptSelectionChanged() => notifyListeners();

  Future<void> init() async {
    await _scriptService.ready;
    final prefs = await SharedPreferences.getInstance();
    _loadIsLocked(prefs);
    _loadCharacterTokens(prefs);
    _loadCharacterAliveState(prefs);
    _loadPlayerNames(prefs);
    _loadNightCount(prefs);
    _currentNightStepId = prefs.getString(_storageNightStepIdKey);
    _loadNightStateNumber(prefs);
    _loadShowCharactersToPlayers(prefs);
    _loadChracterSelectionDone(prefs);
    _loadDemonBluffRoleIds(prefs);
    _loadQuickFlowState(prefs);
    notifyListeners();
  }

  Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_storageIsLockedKey);
    prefs.remove(_storageCharacterTokensKey);
    prefs.remove(_storageCharacterAliveStateKey);
    prefs.remove(_storagePlayerNamesKey);
    prefs.remove(_storageGamesetKey);
    prefs.remove(_storageNightCountKey);
    prefs.remove(_storageNightStateNumberKey);
    prefs.remove(_storageNightStepIdKey);
    prefs.remove(_storageShowCharactersToPlayersKey);
    prefs.remove(_chracterSelectionDoneKey);
    prefs.remove(_storageDemonBluffRoleIdsKey);
    prefs.remove(_storageQuickFlowStateKey);
    init();
  }

  /// Demon bluffs belong to the game setup, but are role identities rather
  /// than character instances. This deliberately keeps them independent from
  /// shuffled player cards and their instance ids.
  List<String> get demonBluffRoleIds => List.unmodifiable(_demonBluffRoleIds);

  bool isDemonBluff(String roleId) => _demonBluffRoleIds.contains(roleId);

  int requiredDemonBluffCount(int regularPlayerCount) =>
      regularPlayerCount >= 7 ? 3 : 0;

  bool hasRequiredDemonBluffs(int regularPlayerCount) =>
      _demonBluffRoleIds.length == requiredDemonBluffCount(regularPlayerCount);

  void _loadDemonBluffRoleIds(SharedPreferences prefs) {
    final raw = prefs.getString(_storageDemonBluffRoleIdsKey);
    if (raw == null) {
      _demonBluffRoleIds = [];
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _demonBluffRoleIds = decoded
            .whereType<String>()
            .where((roleId) => roleId.isNotEmpty)
            .toSet()
            .take(3)
            .toList();
      }
    } catch (_) {
      // A malformed optional setup field must not make an existing game
      // unloadable. It is treated like the pre-bluff save format.
      _demonBluffRoleIds = [];
    }
  }

  Future<void> _saveDemonBluffRoleIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageDemonBluffRoleIdsKey,
      jsonEncode(_demonBluffRoleIds),
    );
  }

  Future<bool> toggleDemonBluff(
    String roleId, {
    required bool isEligible,
    required bool isGameCharacter,
  }) async {
    if (!isEligible || isGameCharacter) {
      return false;
    }
    if (_demonBluffRoleIds.contains(roleId)) {
      _demonBluffRoleIds.remove(roleId);
    } else {
      if (_demonBluffRoleIds.length >= 3) {
        return false;
      }
      _demonBluffRoleIds.add(roleId);
    }
    notifyListeners();
    await _saveDemonBluffRoleIds();
    return true;
  }

  Future<void> setDemonBluffRoleIds(Iterable<String> roleIds) async {
    final normalized = roleIds.where((roleId) => roleId.isNotEmpty).toSet();
    if (normalized.length > 3) {
      throw ArgumentError.value(roleIds, 'roleIds', 'At most three bluffs');
    }
    _demonBluffRoleIds = normalized.toList();
    notifyListeners();
    await _saveDemonBluffRoleIds();
  }

  Future<void> clearDemonBluffs() => setDemonBluffRoleIds(const []);

  void _loadQuickFlowState(SharedPreferences prefs) {
    _clearQuickFlowRuntime();
    final raw = prefs.getString(_storageQuickFlowStateKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return;
      final selections = json['characterSelections'];
      if (selections is Map) {
        for (final entry in selections.entries) {
          if (entry.key is String && entry.value is String) {
            _quickFlowCharacterSelections[entry.key as String] =
                entry.value as String;
          }
        }
      }
      final overrides = json['manualOverrides'];
      if (overrides is List) {
        _quickFlowManualOverrides.addAll(overrides.whereType<String>());
      }
      final stepTargets = json['stepTargets'];
      if (stepTargets is Map) {
        for (final entry in stepTargets.entries) {
          if (entry.key is String && entry.value is List) {
            _quickFlowStepTargets[entry.key as String] =
                (entry.value as List).whereType<String>().toList();
          }
        }
      }
      final confirmations = json['confirmedInfo'];
      if (confirmations is List) {
        _quickFlowConfirmedInfo.addAll(confirmations.whereType<String>());
      }
      final baselines = json['nightBaselines'];
      if (baselines is Map) {
        for (final entry in baselines.entries) {
          if (entry.key is! String || entry.value is! Map) continue;
          final value = entry.value as Map;
          final night = value['night'];
          final targetId = value['targetId'];
          if (night is int && targetId is String) {
            _quickFlowNightBaselines[entry.key as String] =
                _QuickFlowNightBaseline(night, targetId);
          }
        }
      }
      _activeQuickFlowContextKey = json['activeContextKey'] as String?;
      _activeQuickFlowStepKey = json['activeStepKey'] as String?;
    } catch (_) {
      _clearQuickFlowRuntime();
    }
  }

  Future<void> _saveQuickFlowState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageQuickFlowStateKey,
      jsonEncode({
        'characterSelections': _quickFlowCharacterSelections,
        'stepTargets': _quickFlowStepTargets,
        'manualOverrides': _quickFlowManualOverrides.toList(),
        'confirmedInfo': _quickFlowConfirmedInfo.toList(),
        'nightBaselines': _quickFlowNightBaselines.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'activeContextKey': _activeQuickFlowContextKey,
        'activeStepKey': _activeQuickFlowStepKey,
      }),
    );
  }

  void _clearQuickFlowRuntime() {
    _quickFlowCharacterSelections.clear();
    _quickFlowStepTargets.clear();
    _quickFlowManualOverrides.clear();
    _quickFlowConfirmedInfo.clear();
    _quickFlowNightBaselines.clear();
    _activeQuickFlowContextKey = null;
    _activeQuickFlowStepKey = null;
  }

  Future<void> _resetQuickFlowRuntime() async {
    _clearQuickFlowRuntime();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageQuickFlowStateKey);
  }

  int? get openMenuId => _openMenuId;

  void openMenu(int menuId) {
    if (_openMenuId != menuId) {
      Future.delayed(const Duration(seconds: 3), () {
        _openMenuId = null;
      });
      _openMenuId = menuId;
      notifyListeners();
    }
  }

  void openTokenMenu(String tokenID) {
    if (openTokenMenuId != tokenID) {
      Future.delayed(const Duration(seconds: 2), () {
        openTokenMenuId = null;
        notifyListeners();
      });
      openTokenMenuId = tokenID;
      notifyListeners();
    }
  }

  void toggleForceUpdateLayout() {
    _forceUpdateLayout = !_forceUpdateLayout;
    notifyListeners();
  }

  get forceUpdateLayout => _forceUpdateLayout;

  void closeMenu() {
    if (_openMenuId == null && openTokenMenuId == null) {
      return;
    }
    _openMenuId = null;
    openTokenMenuId = null;
    notifyListeners();
  }

  Future<void> _saveCharacterTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_characterTokens.map((key, value) =>
        MapEntry(key, value.map((item) => item.toJson()).toList())));
    await prefs.setString(_storageCharacterTokensKey, data);
  }

  Future<void> _saveCharacterAliveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageCharacterAliveStateKey, jsonEncode(_characterAliveState));
  }

  Future<void> resetCharacterTokens(List<Character> gameCharacters) async {
    _characterTokens.clear();
    unsedGameTokens.clear();
    initUnusedGameTokens(gameCharacters);
    if (!gameIsRunning()) {
      await _resetQuickFlowRuntime();
    }
    await _saveCharacterTokens();
    notifyListeners();
  }

  Future<void> giveAllTokensFromCharacterAToCharacterB(
      List<Character> allCharacters, Character characterA, String eid) async {
    if (characterA.id == eid) {
      return;
    }
    if (_characterTokens.containsKey(characterA.id)) {
      final tokensFromA = _characterTokens.remove(characterA.id) ?? [];
      _characterTokens.putIfAbsent(eid, () => []).addAll(tokensFromA);
    }
    if (_characterAliveState.containsKey(characterA.id)) {
      _characterAliveState[eid] = _characterAliveState.remove(characterA.id)!;
    }
    await Future.wait([
      _saveCharacterTokens(),
      _saveCharacterAliveState(),
    ]);
    notifyListeners();
  }

  Future<void> reset(List<Character> gameCharacters) async {
    await Future.wait([
      resetCharacterTokens(gameCharacters),
      resetCharacterAliveState(),
    ]);
  }

  void _loadIsLocked(SharedPreferences prefs) {
    final bool? isLocked = prefs.getBool(_storageIsLockedKey);
    if (isLocked != null) {
      _isLocked = isLocked;
    }
  }

  void _loadNightCount(SharedPreferences prefs) {
    final int? nightCount = prefs.getInt(_storageNightCountKey);
    if (nightCount != null) {
      _nightCount = nightCount;
    }
  }

  void _loadChracterSelectionDone(SharedPreferences prefs) {
    final bool? chracterSelectionDone =
        prefs.getBool(_chracterSelectionDoneKey);
    if (chracterSelectionDone != null) {
      _chracterSelectionDone = chracterSelectionDone;
    }
  }

  Future<void> setChracterSelectionDone(bool chracterSelectionDone) async {
    if (_chracterSelectionDone == chracterSelectionDone) {
      return;
    }
    _chracterSelectionDone = chracterSelectionDone;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_chracterSelectionDoneKey, chracterSelectionDone);
    notifyListeners();
  }

  void _loadNightStateNumber(SharedPreferences prefs) {
    final double? nightStateNumber =
        prefs.getDouble(_storageNightStateNumberKey);
    if (nightStateNumber != null) {
      _nightStateNumber = nightStateNumber;
      if (_currentNightStepId == null) {
        _legacyNightStateNumber = nightStateNumber;
      }
    }
  }

  Future<void> setShowCharactersToPlayers(bool showCharactersToPlayers) async {
    if (charactersWhereShownToPlayers == showCharactersToPlayers) {
      return;
    }
    charactersWhereShownToPlayers = showCharactersToPlayers;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_storageShowCharactersToPlayersKey, showCharactersToPlayers);
    notifyListeners();
  }

  void _loadShowCharactersToPlayers(SharedPreferences prefs) {
    final bool? showCharactersToPlayers =
        prefs.getBool(_storageShowCharactersToPlayersKey);
    if (showCharactersToPlayers != null) {
      charactersWhereShownToPlayers = showCharactersToPlayers;
    }
  }

  void _loadPlayerNames(SharedPreferences prefs) {
    final String? playerNamesJson = prefs.getString(_storagePlayerNamesKey);
    if (playerNamesJson != null) {
      final List<dynamic> playerNamesList = jsonDecode(playerNamesJson);
      playerNames.clear();
      playerNames.addAll(playerNamesList.map((item) => item.toString()));
    }
  }

  void _loadCharacterTokens(SharedPreferences prefs) {
    final String? characterTokensJson =
        prefs.getString(_storageCharacterTokensKey);
    if (characterTokensJson != null) {
      final Map<String, dynamic> characterTokensMap =
          jsonDecode(characterTokensJson);
      _characterTokens.clear();
      characterTokensMap.forEach((key, value) {
        final List<dynamic> tokenList = value;
        _characterTokens[key] =
            tokenList.map((item) => Token.fromJson(item)).toList();
      });
    }
  }

  void _loadCharacterAliveState(SharedPreferences prefs) {
    final String? characterAliveStateJson =
        prefs.getString(_storageCharacterAliveStateKey);
    if (characterAliveStateJson != null) {
      final Map<String, dynamic> characterAliveStateMap =
          jsonDecode(characterAliveStateJson);
      _characterAliveState.clear();
      characterAliveStateMap.forEach((key, value) {
        _characterAliveState[key] = value;
      });
    }
  }

  List<Token> getUnassignedSetupTokens(List<Character> gameCharacters) {
    List<Token> unassignedSetupTokens = [];
    for (var character in gameCharacters) {
      for (var token in character.tokens) {
        if (!isTokenUsed(token) && token.needsSetup) {
          unassignedSetupTokens.add(token);
        }
      }
    }
    return unassignedSetupTokens;
  }

  Future<void> setGameset(
      Gameset gameset, List<Character> gameCharacters) async {
    final changed = await selectScript(
      ScriptService.idForGameset(gameset),
      gameCharacters,
    );
    if (!changed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageGamesetKey, gameset.toString());
  }

  Future<bool> selectScript(
      String scriptId, List<Character> gameCharacters) async {
    final changed = await _scriptService.selectScript(
      scriptId,
      gameIsRunning: gameIsRunning(),
    );
    if (!changed) return false;
    await clearDemonBluffs();
    reset(gameCharacters);
    notifyListeners();
    return true;
  }

  /// Deletes a custom script only outside an active game. If the deleted
  /// script was selected, the script service returns to Trouble Brewing and
  /// the game-only state is reset by the caller's current character list.
  Future<bool> removeCustomScript(
    String scriptId,
    List<Character> gameCharacters,
  ) async {
    if (gameIsRunning()) return false;
    final wasSelected = _scriptService.selectedScriptId == scriptId;
    final removed = await _scriptService.removeScript(
      scriptId,
      gameIsRunning: false,
    );
    if (!removed) return false;
    if (wasSelected) {
      await reset(gameCharacters);
    }
    notifyListeners();
    return true;
  }

  void addPlayerName(String playerName) async {
    if (playerName.isEmpty) {
      return;
    }
    playerNames.add(playerName); // _playerNames bleibt List<String>
    final prefs = await SharedPreferences.getInstance();
    final String data =
        jsonEncode(playerNames); // Liste von Strings wird gespeichert
    prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  void removePlayerName(String playerName) async {
    if (!playerNames.contains(playerName)) {
      return;
    }
    playerNames.remove(playerName);
    final prefs = await SharedPreferences.getInstance();
    final String data =
        jsonEncode(playerNames); // JSON enthält Liste von Strings
    prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  void clearAllPlayerNames() async {
    if (playerNames.isEmpty) {
      return;
    }
    playerNames.clear();
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(playerNames);
    prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  void initUnusedGameTokens(List<Character> gameCharacters) {
    // The active character list is the token inventory.  Backups contain
    // independent copies of those characters and must never contribute extra
    // reminder tokens.
    unsedGameTokens.clear();

    // Token assignments are persisted as JSON and therefore are recreated as
    // different Dart objects after an app restart.  Reconnect each persisted
    // assignment to one concrete token from the active inventory.  This keeps
    // identity based movement working while treating the inventory as a
    // multiset: two equal-looking reminders from two role instances remain two
    // separate available tokens.
    final availableTokens = <Token>[];
    for (var character in gameCharacters) {
      for (final token in character.tokens) {
        availableTokens.add(token);
      }
    }

    for (final assignedTokens in _characterTokens.values) {
      for (var index = 0; index < assignedTokens.length; index++) {
        final assignedToken = assignedTokens[index];
        var matchingIndex = availableTokens.indexWhere((token) =>
            _tokenDefinitionKey(token) == _tokenDefinitionKey(assignedToken));
        if (matchingIndex < 0 &&
            (assignedToken.quickId == null ||
                assignedToken.ownerRoleInstanceId.isEmpty)) {
          matchingIndex = availableTokens.indexWhere((token) =>
              _legacyTokenDefinitionKey(token) ==
              _legacyTokenDefinitionKey(assignedToken));
        }

        // Unlimited tokens deliberately may be attached more than once. They
        // keep their existing behavior and do not consume the single catalog
        // definition from the inventory.
        if (assignedToken.unlimited) {
          if (matchingIndex >= 0) {
            assignedTokens[index] = availableTokens[matchingIndex];
          }
          continue;
        }

        if (matchingIndex >= 0) {
          assignedTokens[index] = availableTokens.removeAt(matchingIndex);
        }
      }
    }

    unsedGameTokens.addAll(availableTokens);
  }

  String _tokenDefinitionKey(Token token) => jsonEncode(token.toJson());

  String _legacyTokenDefinitionKey(Token token) => jsonEncode({
        'name': token.name,
        'image': token.image,
        'unlimited': token.unlimited,
        'needsSetup': token.needsSetup,
      });

  Future<void> endGame() async {
    final resetFuture = Future.wait([
      resetCharacterTokens([]),
      resetCharacterAliveState(),
      clearDemonBluffs(),
      _resetQuickFlowRuntime(),
    ]);
    _nightCount = -1;
    _nightStateNumber = 0;
    _currentNightStepId = null;
    _legacyNightStateNumber = null;
    await resetFuture;
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_storageNightCountKey);
    prefs.remove(_storageNightStateNumberKey);
    prefs.remove(_storageNightStepIdKey);
    notifyListeners();
  }

  Future<void> startNewGame(List<Character> gameCharacters) async {
    await _nightOrderService.ready;
    _nightCount = 1;
    final steps = _stepsFor(gameCharacters);
    await _setNightStep(steps.isEmpty ? 'day' : steps.first.id);
  }

  bool isCharacterAwake(Character character) {
    final stepId = _currentNightStepId;
    return stepId == 'role:${character.roleId}:${character.id}';
  }

  /// Resolves the visible night-order highlight from the active step and the
  /// current character instances. Info phases deliberately use the current
  /// fraction, so custom scripts and changed roles work without relying on a
  /// catalog-wide role list.
  bool isCharacterHighlighted(Character character) {
    if (isCharacterAwake(character)) return true;
    return switch (_currentNightStepId) {
      'phase:minioninfo' => character.fraction == Fraction.minion,
      'phase:demoninfo' => character.fraction == Fraction.demon,
      _ => false,
    };
  }

  List<Character> highlightedNightCharacters(List<Character> gameCharacters) {
    return gameCharacters.where(isCharacterHighlighted).toList();
  }

  Character? getAwakeCharacter(List<Character> gameCharacters) {
    _ensureCurrentNightStep(gameCharacters);
    return gameCharacters.firstWhereOrNull(isCharacterAwake);
  }

  bool isMinionInfo() => _currentNightStepId == 'phase:minioninfo';

  bool isDemonInfo() => _currentNightStepId == 'phase:demoninfo';

  String getNightStateHelpText(
    Character? character, {
    List<Character>? gameCharacters,
    String languageCode = 'en',
  }) {
    final characters = gameCharacters ??
        (character == null ? const <Character>[] : <Character>[character]);
    final step = currentNightStep(characters);
    if (step == null) return '';
    return _nightOrderService.instructionFor(step, _nightCount, languageCode);
  }

  String getNightStanteHelpTitle(
    Character? character, {
    List<Character>? gameCharacters,
    String languageCode = 'en',
  }) {
    final characters = gameCharacters ??
        (character == null ? const <Character>[] : <Character>[character]);
    final step = currentNightStep(characters);
    if (step == null) return '';
    return _nightOrderService.titleFor(step, languageCode);
  }

  bool showNightStateHelpButton() {
    final stepId = _currentNightStepId;
    return _nightCount > 0 &&
        stepId != null &&
        stepId != 'day' &&
        stepId != 'phase:dusk' &&
        stepId != 'phase:dawn';
  }

  bool gameIsRunning() {
    return _nightCount > 0;
  }

  bool isDawn() => _currentNightStepId == 'phase:dawn';

  bool isDay() => _currentNightStepId == 'day';

  bool isDust() => _currentNightStepId == 'phase:dusk';

  Future<void> previousNightState(List<Character> characters) async {
    await _nightOrderService.ready;
    _ensureCurrentNightStep(characters);
    if (_currentNightStepId == 'day') {
      final steps = _stepsFor(characters);
      if (steps.isNotEmpty) await _setNightStep(steps.last.id);
      return;
    }
    var steps = _stepsFor(characters);
    final currentIndex =
        steps.indexWhere((step) => step.id == _currentNightStepId);
    if (currentIndex > 0) {
      await _setNightStep(steps[currentIndex - 1].id);
      return;
    }
    if (_nightCount <= 1) return;
    _nightCount--;
    steps = _stepsFor(characters);
    await _setNightStep(steps.isEmpty ? 'day' : steps.last.id);
  }

  Future<void> nextNightState(List<Character> gameCharacters) async {
    await _nightOrderService.ready;
    closeMenu();
    _ensureCurrentNightStep(gameCharacters);
    if (_currentNightStepId == 'day') {
      await nextNight(gameCharacters);
      return;
    }
    final steps = _stepsFor(gameCharacters);
    final currentIndex =
        steps.indexWhere((step) => step.id == _currentNightStepId);
    if (currentIndex >= 0 && currentIndex + 1 < steps.length) {
      await _setNightStep(steps[currentIndex + 1].id);
      return;
    }
    if (currentIndex < 0 && _currentNightStepId != null) {
      final currentOrderIndex = _nightOrderService.orderIndexForStep(
        _currentNightStepId!,
        _nightCount,
      );
      final next = steps.firstWhereOrNull((step) =>
          _nightOrderService.orderIndexForStep(step.id, _nightCount) >
          currentOrderIndex);
      if (next != null) {
        await _setNightStep(next.id);
        return;
      }
    }
    await startDay();
  }

  Future<void> startDay() async {
    await _setNightStep('day');
  }

  Future<void> nextNight([List<Character> gameCharacters = const []]) async {
    await _nightOrderService.ready;
    _nightCount++;
    final steps = _stepsFor(gameCharacters);
    await _setNightStep(steps.isEmpty ? 'day' : steps.first.id);
  }

  Future<void> previousNight(
      [List<Character> gameCharacters = const []]) async {
    await _nightOrderService.ready;
    if (_nightCount == 1) {
      return;
    }
    _nightCount--;
    final steps = _stepsFor(gameCharacters);
    await _setNightStep(steps.isEmpty ? 'day' : steps.last.id);
  }

  List<NightStep> _stepsFor(List<Character> gameCharacters) {
    final travellerCount = gameCharacters
        .where((character) => character.fraction.name == 'traveller')
        .length;
    final regularPlayerCount = max(0, playerNames.length - travellerCount);
    return _nightOrderService.stepsFor(
      nightCount: _nightCount,
      gameCharacters: gameCharacters,
      regularPlayerCount: regularPlayerCount,
      isAlive: isCharacterAlive,
    );
  }

  NightStep? currentNightStep(List<Character> gameCharacters) {
    _ensureCurrentNightStep(gameCharacters);
    return _stepsFor(gameCharacters)
        .firstWhereOrNull((step) => step.id == _currentNightStepId);
  }

  Future<void> synchronizeNightStep(List<Character> gameCharacters) async {
    await _nightOrderService.ready;
    if (_ensureCurrentNightStep(gameCharacters)) {
      notifyListeners();
    }
  }

  bool _ensureCurrentNightStep(List<Character> gameCharacters) {
    if (!_nightOrderService.isReady ||
        _nightCount < 1 ||
        _currentNightStepId == 'day') {
      return false;
    }
    final steps = _stepsFor(gameCharacters);
    if (_currentNightStepId != null) {
      if (steps.any((step) => step.id == _currentNightStepId)) return false;
      final missingOrderIndex = _nightOrderService.orderIndexForStep(
        _currentNightStepId!,
        _nightCount,
      );
      _currentNightStepId = steps
              .firstWhereOrNull((step) =>
                  _nightOrderService.orderIndexForStep(step.id, _nightCount) >
                  missingOrderIndex)
              ?.id ??
          'day';
      unawaited(_persistNightPosition());
      return true;
    }
    final legacy = _legacyNightStateNumber;
    if (legacy == 0) {
      _currentNightStepId = 'day';
    } else if (legacy == 1) {
      _currentNightStepId = 'phase:dusk';
    } else if (_nightCount == 1 &&
        legacy != null &&
        legacy >= 2 &&
        legacy <= 2.7) {
      _currentNightStepId = 'phase:minioninfo';
    } else if (_nightCount == 1 &&
        legacy != null &&
        legacy >= 3 &&
        legacy <= 3.7) {
      _currentNightStepId = 'phase:demoninfo';
    } else if (legacy != null) {
      final legacyCharacters = gameCharacters
          .where((character) => (_nightCount == 1
                  ? character.nightStateNumbersFirstNight
                  : character.nightStateNumbersOtherNights)
              .contains(legacy))
          .toList();
      if (legacyCharacters.length == 1) {
        final legacyCharacter = legacyCharacters.single;
        _currentNightStepId =
            'role:${legacyCharacter.roleId}:${legacyCharacter.id}';
      }
    }
    _currentNightStepId ??= steps.isEmpty ? 'day' : steps.first.id;
    _legacyNightStateNumber = null;
    unawaited(_persistNightPosition());
    return true;
  }

  Future<void> _setNightStep(String stepId) async {
    _currentNightStepId = stepId;
    _legacyNightStateNumber = null;
    _nightStateNumber = stepId == 'day' ? 0 : 1;
    await _persistNightPosition();
    notifyListeners();
  }

  Future<void> _persistNightPosition() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_storageNightCountKey, _nightCount);
    if (_currentNightStepId == null) {
      prefs.remove(_storageNightStepIdKey);
    } else {
      prefs.setString(_storageNightStepIdKey, _currentNightStepId!);
    }
    prefs.remove(_storageNightStateNumberKey);
  }

  List<QuickFlowEntry> quickFlowEntries(List<Character> gameCharacters) {
    if (_nightCount <= 0 ||
        (_nightCount == 1 && _currentNightStepId == 'phase:dusk')) {
      return [
        for (final character in gameCharacters)
          for (final step in character.quickFlow.stepsFor(QuickFlowPhase.setup))
            QuickFlowEntry(
              owner: character,
              phase: QuickFlowPhase.setup,
              step: step,
            ),
      ];
    }
    if (_currentNightStepId == 'day' || _currentNightStepId == 'phase:dawn') {
      return const [];
    }
    final owner = getAwakeCharacter(gameCharacters);
    if (owner == null) return const [];
    final phase = _nightCount == 1
        ? QuickFlowPhase.firstNight
        : QuickFlowPhase.otherNights;
    return [
      for (final step in owner.quickFlow.stepsFor(phase))
        QuickFlowEntry(owner: owner, phase: phase, step: step),
    ];
  }

  String? _quickFlowContextKey(List<QuickFlowEntry> entries) {
    if (entries.isEmpty) return null;
    if (entries.first.phase == QuickFlowPhase.setup) {
      return 'setup:${_nightCount <= 0 ? 0 : 1}';
    }
    return '${entries.first.owner.id}:${entries.first.phase.name}:$_nightCount';
  }

  Token? quickFlowToken(QuickFlowEntry entry) {
    if (entry.step.type != QuickFlowStepType.reminder) return null;
    final matches = entry.owner.tokens
        .where((token) => token.quickId == entry.step.tokenId)
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  bool isQuickFlowEntrySupported(QuickFlowEntry entry) {
    return _quickFlowInterpreter.isStepSupported(
      entry.step,
      token: quickFlowToken(entry),
    );
  }

  QuickFlowEntry? activeQuickFlowReminder(List<Character> gameCharacters) {
    final entries = quickFlowEntries(gameCharacters);
    final contextKey = _quickFlowContextKey(entries);
    if (contextKey == null) return null;
    if (_activeQuickFlowContextKey != contextKey) {
      return entries.firstWhereOrNull((entry) =>
          entry.step.type == QuickFlowStepType.reminder &&
          isQuickFlowEntrySupported(entry));
    }
    return entries.firstWhereOrNull((entry) =>
        entry.key == _activeQuickFlowStepKey &&
        entry.step.type == QuickFlowStepType.reminder &&
        isQuickFlowEntrySupported(entry));
  }

  bool isQuickFlowEntryActive(
          QuickFlowEntry entry, List<Character> gameCharacters) =>
      activeQuickFlowReminder(gameCharacters)?.key == entry.key;

  Future<void> activateQuickFlowEntry(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) async {
    if (!isQuickFlowEntrySupported(entry) ||
        entry.step.type != QuickFlowStepType.reminder) {
      return;
    }
    _activeQuickFlowContextKey =
        _quickFlowContextKey(quickFlowEntries(gameCharacters));
    _activeQuickFlowStepKey = entry.key;
    await _saveQuickFlowState();
    notifyListeners();
  }

  List<Character> quickFlowTargets(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) {
    final token = quickFlowToken(entry);
    if (token == null) return const [];
    final actualTargets = gameCharacters
        .where((character) => tokensOfCharacter(character).contains(token))
        .toList(growable: false);
    final siblings = _sharedQuickFlowReminderEntries(entry);
    if (siblings.length < 2) return actualTargets;

    final storedIds = _quickFlowStepTargets[entry.key];
    if (storedIds != null) {
      return actualTargets
          .where((character) => storedIds.contains(character.id))
          .toList(growable: false);
    }
    final claimedByOtherSteps = siblings
        .where((sibling) => sibling.key != entry.key)
        .expand((sibling) => _quickFlowStepTargets[sibling.key] ?? const [])
        .toSet();
    if (claimedByOtherSteps.isEmpty && siblings.first.key == entry.key) {
      return actualTargets;
    }
    return actualTargets
        .where((character) => !claimedByOtherSteps.contains(character.id))
        .toList(growable: false);
  }

  List<QuickFlowEntry> _sharedQuickFlowReminderEntries(QuickFlowEntry entry) {
    final group = entry.step.group;
    if (group == null ||
        entry.step.operation != QuickFlowReminderOperation.append) {
      return [entry];
    }
    return entry.owner.quickFlow
        .stepsFor(entry.phase)
        .where((step) =>
            step.type == QuickFlowStepType.reminder &&
            step.operation == QuickFlowReminderOperation.append &&
            step.group == group &&
            step.tokenId == entry.step.tokenId)
        .map((step) =>
            QuickFlowEntry(owner: entry.owner, phase: entry.phase, step: step))
        .toList(growable: false);
  }

  void _recordQuickFlowStepTarget(QuickFlowEntry entry, Character target) {
    if (entry.step.operation != QuickFlowReminderOperation.append) return;
    final targets =
        _quickFlowStepTargets.putIfAbsent(entry.key, () => <String>[]);
    if (!targets.contains(target.id)) targets.add(target.id);
  }

  Character? quickFlowTarget(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) =>
      quickFlowTargets(entry, gameCharacters).firstOrNull;

  QuickFlowEntry? _entryForStepId(
    Character owner,
    QuickFlowPhase preferredPhase,
    String stepId,
  ) {
    final phases = <QuickFlowPhase>[
      preferredPhase,
      ...QuickFlowPhase.values.where((phase) => phase != preferredPhase),
    ];
    for (final phase in phases) {
      final step = owner.quickFlow
          .stepsFor(phase)
          .firstWhereOrNull((candidate) => candidate.id == stepId);
      if (step != null) {
        return QuickFlowEntry(owner: owner, phase: phase, step: step);
      }
    }
    return null;
  }

  bool _isQuickFlowTargetAllowed(
    QuickFlowEntry entry,
    Character target,
    List<Character> gameCharacters,
  ) {
    final rules = entry.step.allowedTargets;
    if (!_quickFlowInterpreter.matchesStaticTargetRules(
      entry.step,
      entry.owner,
      target,
      targetIsAlive: isCharacterAlive(target),
    )) {
      return false;
    }

    final referencedTargets = <String, Character?>{
      for (final stepId in {
        ...entry.step.distinctFrom,
        ...rules.mustMatchOneOf,
      })
        stepId: _entryForStepId(entry.owner, entry.phase, stepId) == null
            ? null
            : quickFlowTarget(
                _entryForStepId(entry.owner, entry.phase, stepId)!,
                gameCharacters,
              ),
    };
    if (entry.step.distinctFrom
        .any((stepId) => referencedTargets[stepId]?.id == target.id)) {
      return false;
    }
    if (rules.mustMatchOneOf.isNotEmpty &&
        !rules.mustMatchOneOf
            .any((stepId) => referencedTargets[stepId]?.id == target.id)) {
      return false;
    }
    return true;
  }

  bool _hasResolvableQuickFlowTargetReferences(QuickFlowEntry entry) {
    final referencedStepIds = {
      ...entry.step.distinctFrom,
      ...entry.step.allowedTargets.mustMatchOneOf,
    };
    return referencedStepIds.every((stepId) {
      final referenced = _entryForStepId(entry.owner, entry.phase, stepId);
      return referenced != null &&
          referenced.step.type == QuickFlowStepType.reminder &&
          quickFlowToken(referenced) != null;
    });
  }

  Future<void> _ensureQuickFlowNightBaseline(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) async {
    if (entry.step.nightConstraint != 'differentFromPreviousNight') return;
    final baselineKey = '${entry.owner.id}:${entry.step.id}';
    final existing = _quickFlowNightBaselines[baselineKey];
    if (existing?.night == _nightCount) return;
    _quickFlowNightBaselines[baselineKey] = _QuickFlowNightBaseline(
      _nightCount,
      quickFlowTarget(entry, gameCharacters)?.id ?? '',
    );
    await _saveQuickFlowState();
  }

  Future<QuickFlowAssignmentResult> assignActiveQuickFlowReminder(
    List<Character> gameCharacters,
    Character target,
  ) async {
    final entry = activeQuickFlowReminder(gameCharacters);
    if (entry == null) return const QuickFlowAssignmentResult.notHandled();
    final token = quickFlowToken(entry);
    if (token == null ||
        !gameCharacters.any((character) => character.id == target.id) ||
        !_hasResolvableQuickFlowTargetReferences(entry) ||
        !isQuickFlowEntrySupported(entry)) {
      return const QuickFlowAssignmentResult.failure(
        QuickFlowAssignmentFailure.unsupported,
      );
    }
    await _ensureQuickFlowNightBaseline(entry, gameCharacters);
    QuickFlowAssignmentFailure? warning;
    if (!_isQuickFlowTargetAllowed(entry, target, gameCharacters)) {
      warning = QuickFlowAssignmentFailure.invalidTarget;
    }
    if (entry.step.nightConstraint == 'differentFromPreviousNight') {
      final previous =
          _quickFlowNightBaselines['${entry.owner.id}:${entry.step.id}'];
      if (previous != null &&
          previous.targetId.isNotEmpty &&
          previous.targetId == target.id) {
        warning = QuickFlowAssignmentFailure.previousNightTarget;
      }
    }
    final currentTargets = quickFlowTargets(entry, gameCharacters);
    if (currentTargets.any((character) => character.id == target.id)) {
      _recordQuickFlowStepTarget(entry, target);
      await _advanceQuickFlowAfter(entry, gameCharacters);
      return QuickFlowAssignmentResult.success(warning: warning);
    }
    if (entry.step.operation == QuickFlowReminderOperation.append &&
        currentTargets.any((character) => character.id == target.id)) {
      return const QuickFlowAssignmentResult.failure(
        QuickFlowAssignmentFailure.duplicateTarget,
      );
    }
    if (entry.step.operation == QuickFlowReminderOperation.append &&
        tokensOfCharacter(target).contains(token)) {
      _recordQuickFlowStepTarget(entry, target);
      await _advanceQuickFlowAfter(entry, gameCharacters);
      return QuickFlowAssignmentResult.success(warning: warning);
    }
    await addTokenToCharacter(gameCharacters, target, token);
    _recordQuickFlowStepTarget(entry, target);
    await _advanceQuickFlowAfter(entry, gameCharacters);
    return QuickFlowAssignmentResult.success(warning: warning);
  }

  Future<void> _advanceQuickFlowAfter(
    QuickFlowEntry current,
    List<Character> gameCharacters,
  ) async {
    final entries = quickFlowEntries(gameCharacters);
    _activeQuickFlowContextKey = _quickFlowContextKey(entries);
    final currentIndex =
        entries.indexWhere((entry) => entry.key == current.key);
    _activeQuickFlowStepKey = currentIndex < 0
        ? null
        : entries
            .skip(currentIndex + 1)
            .firstWhereOrNull((entry) =>
                entry.step.type == QuickFlowStepType.reminder &&
                isQuickFlowEntrySupported(entry))
            ?.key;
    await _saveQuickFlowState();
    notifyListeners();
  }

  Character? quickFlowSelectedCharacter(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    if (entry.step.type != QuickFlowStepType.reminderCharacterToken) {
      return null;
    }
    final storedRoleId = _quickFlowCharacterSelections[entry.key];
    if (storedRoleId != null &&
        (_quickFlowManualOverrides.contains(entry.key) ||
            entry.step.selection?.type == 'manual')) {
      final stored = allCharacters.firstWhereOrNull(
        (character) => character.roleId == storedRoleId,
      );
      if (stored != null && _isQuickFlowCharacterAllowed(entry, stored)) {
        return stored;
      }
    }
    final sourceStepId = entry.step.selection?.stepId;
    if (entry.step.selection?.type == 'fromReminderTarget' &&
        sourceStepId != null) {
      final source = _entryForStepId(entry.owner, entry.phase, sourceStepId);
      final target =
          source == null ? null : quickFlowTarget(source, gameCharacters);
      if (target != null && _isQuickFlowCharacterAllowed(entry, target)) {
        return allCharacters.firstWhereOrNull(
              (character) => character.roleId == target.roleId,
            ) ??
            target;
      }
    }
    return null;
  }

  bool _isQuickFlowCharacterAllowed(
          QuickFlowEntry entry, Character character) =>
      _quickFlowInterpreter.isCharacterAllowed(entry.step, character);

  List<Character> quickFlowCharacterChoices(
    QuickFlowEntry entry,
    List<Character> allCharacters,
  ) {
    final seen = <String>{};
    return allCharacters
        .where((character) =>
            _isQuickFlowCharacterAllowed(entry, character) &&
            seen.add(character.roleId))
        .toList(growable: false);
  }

  Future<bool> setQuickFlowSelectedCharacter(
    QuickFlowEntry entry,
    Character character,
  ) async {
    if (entry.step.type != QuickFlowStepType.reminderCharacterToken ||
        entry.step.selection == null ||
        !_isQuickFlowCharacterAllowed(entry, character) ||
        (entry.step.selection!.type == 'fromReminderTarget' &&
            !entry.step.allowManualOverride)) {
      return false;
    }
    _quickFlowCharacterSelections[entry.key] = character.roleId;
    _quickFlowManualOverrides.add(entry.key);
    await _saveQuickFlowState();
    notifyListeners();
    return true;
  }

  bool isQuickFlowStepComplete(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    switch (entry.step.type) {
      case QuickFlowStepType.reminder:
        return quickFlowTargets(entry, gameCharacters).isNotEmpty;
      case QuickFlowStepType.reminderCharacterToken:
        return quickFlowSelectedCharacter(
              entry,
              gameCharacters,
              allCharacters,
            ) !=
            null;
      case QuickFlowStepType.showInfo:
        return isQuickFlowInfoReady(entry, gameCharacters, allCharacters);
    }
  }

  bool _isQuickFlowRequiredStepComplete(
    QuickFlowEntry infoEntry,
    String stepId,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    final required = _entryForStepId(infoEntry.owner, infoEntry.phase, stepId);
    return required != null &&
        required.step.type != QuickFlowStepType.showInfo &&
        isQuickFlowEntrySupported(required) &&
        isQuickFlowStepComplete(required, gameCharacters, allCharacters);
  }

  bool isQuickFlowInfoReady(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    if (entry.step.type != QuickFlowStepType.showInfo ||
        !isQuickFlowEntrySupported(entry)) {
      return false;
    }
    final recipient = entry.step.recipient;
    final recipientReady = switch (recipient?.type) {
      'abilityOwner' => true,
      'reminderTarget' => recipient?.stepId != null &&
          quickFlowTarget(
                _entryForStepId(
                      entry.owner,
                      entry.phase,
                      recipient!.stepId!,
                    ) ??
                    entry,
                gameCharacters,
              ) !=
              null,
      _ => false,
    };
    return recipientReady &&
        entry.step.requires.every((stepId) => _isQuickFlowRequiredStepComplete(
            entry, stepId, gameCharacters, allCharacters));
  }

  String _quickFlowConfirmationKey(QuickFlowEntry entry) =>
      '${entry.key}:night:$_nightCount';

  bool quickFlowInfoNeedsConfirmation(QuickFlowEntry entry) =>
      entry.step.showOnlyWhen?.type == 'storytellerConfirmed' &&
      !_quickFlowConfirmedInfo.contains(_quickFlowConfirmationKey(entry));

  Future<void> confirmQuickFlowInfo(QuickFlowEntry entry) async {
    _quickFlowConfirmedInfo.add(_quickFlowConfirmationKey(entry));
    await _saveQuickFlowState();
    notifyListeners();
  }

  QuickFlowInfo? buildQuickFlowInfo(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    if (!isQuickFlowInfoReady(entry, gameCharacters, allCharacters) ||
        quickFlowInfoNeedsConfirmation(entry)) {
      return null;
    }
    final presentation = entry.step.presentation!;
    final playerStepIds = <String>[
      ...presentation.playerSteps,
      if (presentation.playerStep != null) presentation.playerStep!,
    ];
    final players = <Character>[];
    for (final stepId in playerStepIds) {
      final playerEntry = _entryForStepId(entry.owner, entry.phase, stepId);
      final target = playerEntry == null
          ? null
          : quickFlowTarget(playerEntry, gameCharacters);
      if (target != null && !players.any((item) => item.id == target.id)) {
        players.add(target);
      }
    }
    final pointToRolePlayer = presentation.pointToRolePlayer;
    if (pointToRolePlayer != null) {
      final target = gameCharacters.firstWhereOrNull(
        (character) => character.roleId == pointToRolePlayer,
      );
      if (target != null && !players.any((item) => item.id == target.id)) {
        players.add(target);
      }
    }
    Character? selectedCharacter;
    if (presentation.characterStep != null) {
      final characterEntry = _entryForStepId(
        entry.owner,
        entry.phase,
        presentation.characterStep!,
      );
      if (characterEntry != null) {
        selectedCharacter = quickFlowSelectedCharacter(
          characterEntry,
          gameCharacters,
          allCharacters,
        );
      }
    }
    final sourceRoleId = presentation.sourceRoleId;
    final sourceCharacter = sourceRoleId == null
        ? entry.owner
        : allCharacters.firstWhereOrNull(
              (character) => character.roleId == sourceRoleId,
            ) ??
            entry.owner;
    return QuickFlowInfo(
      kind: presentation.kind,
      owner: entry.owner,
      sourceCharacter: sourceCharacter,
      selectedCharacter: selectedCharacter,
      players: players,
    );
  }

  Future<void> addRandomUnusedTokensToRandomCharacters(
      List<Character> characters) async {
    _characterTokens.clear();
    final List<Token> unusedTokens = getAllTokensInGame(characters);
    unusedTokens.shuffle();
    final shuffledCharacters = List<Character>.from(characters)..shuffle();
    for (var character in shuffledCharacters) {
      if (unusedTokens.isNotEmpty) {
        var randomInt = Random().nextInt(unusedTokens.length);
        var randomToken = unusedTokens[randomInt];
        _characterTokens[character.id] = [randomToken];
        unusedTokens.remove(randomToken);
      }
    }
    await _saveCharacterTokens();
    notifyListeners();
  }

  bool isTokenUsed(Token token) {
    return _characterTokens.values.any((element) => element.contains(token));
  }

  List<Token> tokensOfCharacter(Character character) {
    return _characterTokens[character.id] ?? [];
  }

  bool isCharacterAlive(Character character) {
    return _characterAliveState[character.id] ?? true;
  }

  Future<void> resetCharacterAliveState() async {
    _characterAliveState.clear();
    await _saveCharacterAliveState();
    notifyListeners();
  }

  Future<void> toggleCharacterAlive(Character character) async {
    if (_characterAliveState.containsKey(character.id)) {
      _characterAliveState[character.id] = !_characterAliveState[character.id]!;
    } else {
      _characterAliveState[character.id] = false;
    }
    await _saveCharacterAliveState();
    notifyListeners();
  }

  Character? getCharacterById(List<Character> characters, String id) {
    return characters.cast<Character?>().firstWhere(
          (element) => element?.id == id,
          orElse: () => null,
        );
  }

  String getCharacterIdByToken(Token token) {
    try {
      return _characterTokens.entries
          .firstWhere((entry) => entry.value.contains(token))
          .key;
    } catch (e) {
      throw Exception('Token not found for any character');
    }
  }

  void reorderPlayerNames(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String playerName = playerNames.removeAt(oldIndex);
    playerNames.insert(newIndex, playerName);
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(playerNames);
    prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  List<Token> getAllTokensInGame(List<Character> gameCharacters) {
    initUnusedGameTokens(gameCharacters);
    final List<Token> allTokens = [];
    for (var tokenList in _characterTokens.values) {
      allTokens.addAll(tokenList);
    }
    allTokens.addAll(unsedGameTokens);
    allTokens.sort((a, b) => a.image.compareTo(b.image));
    return allTokens;
  }

  Future<void> addTokenToCharacter(
      List<Character> allCharacters, Character character, Token token) async {
    if (!_characterTokens.containsKey(character.id)) {
      _characterTokens[character.id] = [];
    }
    if (isTokenUsed(token) && !token.unlimited) {
      final String characterId = getCharacterIdByToken(token);
      _characterTokens[characterId]?.remove(token);
    }
    _characterTokens[character.id]!.add(token);
    unsedGameTokens.remove(token);
    await _saveCharacterTokens();
    notifyListeners();
  }

  Future<void> removeTokenFromCharacter(
      Character character, Token token) async {
    if (_characterTokens.containsKey(character.id)) {
      _characterTokens[character.id]!.remove(token);
      unsedGameTokens.add(token);
      await _saveCharacterTokens();
      notifyListeners();
    }
  }

  void setIsLocked(bool isLocked) async {
    if (_isLocked == isLocked) {
      return;
    }
    _isLocked = isLocked;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_storageIsLockedKey, isLocked);
    notifyListeners();
  }

  void toggleIsLocked() async {
    _isLocked = !_isLocked;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_storageIsLockedKey, _isLocked);
    notifyListeners();
  }

  get isLocked => _isLocked;
  Gameset get gameset => _scriptService.selectedGameset ?? Gameset.experimental;
  String get selectedScriptId => _scriptService.selectedScriptId;
  get nightCount => _nightCount;
  get nightStateNumber => _nightStateNumber;
  String? get currentNightStepId => _currentNightStepId;
  get showCharactersToPlayers => charactersWhereShownToPlayers;
  get characterSelectionDone => _chracterSelectionDone;

  @override
  void dispose() {
    _scriptService.removeListener(_onScriptSelectionChanged);
    super.dispose();
  }
}

class _QuickFlowNightBaseline {
  final int night;
  final String targetId;

  const _QuickFlowNightBaseline(this.night, this.targetId);

  Map<String, dynamic> toJson() => {
        'night': night,
        'targetId': targetId,
      };
}
