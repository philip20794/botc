import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameStateService extends ChangeNotifier {
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
  List<String> _demonBluffRoleIds = [];
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
    final availableByDefinition = <String, List<Token>>{};
    for (var character in gameCharacters) {
      for (final token in character.tokens) {
        availableByDefinition
            .putIfAbsent(_tokenDefinitionKey(token), () => <Token>[])
            .add(token);
      }
    }

    for (final assignedTokens in _characterTokens.values) {
      for (var index = 0; index < assignedTokens.length; index++) {
        final assignedToken = assignedTokens[index];
        final matchingTokens =
            availableByDefinition[_tokenDefinitionKey(assignedToken)];

        // Unlimited tokens deliberately may be attached more than once. They
        // keep their existing behavior and do not consume the single catalog
        // definition from the inventory.
        if (assignedToken.unlimited) {
          if (matchingTokens != null && matchingTokens.isNotEmpty) {
            assignedTokens[index] = matchingTokens.first;
          }
          continue;
        }

        if (matchingTokens != null && matchingTokens.isNotEmpty) {
          assignedTokens[index] = matchingTokens.removeAt(0);
        }
      }
    }

    for (final tokens in availableByDefinition.values) {
      unsedGameTokens.addAll(tokens);
    }
  }

  String _tokenDefinitionKey(Token token) => jsonEncode(token.toJson());

  Future<void> endGame() async {
    final resetFuture = Future.wait([
      resetCharacterTokens([]),
      resetCharacterAliveState(),
      clearDemonBluffs(),
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
