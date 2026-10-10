import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameStateService extends ChangeNotifier {
  final ScriptService _scriptService;
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
  bool charactersWhereShownToPlayers = false;
  final String _storageCharacterTokensKey = 'character_tokens';
  final String _storageCharacterAliveStateKey = 'character_alive_state';
  final String _storagePlayerNamesKey = 'player_names';
  final String _storageGamesetKey = 'gameset';
  final String _storageNightCountKey = 'night_count';
  final String _storageNightStateNumberKey = 'night_state_number';
  final String _storageShowCharactersToPlayersKey =
      'show_characters_to_players';
  final String _chracterSelectionDoneKey = 'character_selection_done';
  static const String _storageDemonBluffRoleIdsKey = 'demon_bluff_role_ids';
  List<String> _demonBluffRoleIds = [];
  int? _openMenuId;
  String? openTokenMenuId;

  GameStateService({ScriptService? scriptService})
      : _scriptService = scriptService ?? ScriptService() {
    _scriptService.addListener(_onScriptSelectionChanged);
    init();
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
    // _characterTokens.clear();
    unsedGameTokens.clear();
    for (var character in gameCharacters) {
      character.tokens.forEach((token) {
        if (!isTokenUsed(token)) {
          unsedGameTokens.add(token);
        }
      });
    }
  }

  Future<void> endGame() async {
    final resetFuture = Future.wait([
      resetCharacterTokens([]),
      resetCharacterAliveState(),
      clearDemonBluffs(),
    ]);
    _nightCount = -1;
    _nightStateNumber = 0;
    await resetFuture;
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_storageNightCountKey);
    prefs.remove(_storageNightStateNumberKey);
    notifyListeners();
  }

  Future<void> startNewGame(List<Character> gameCharacters) async {
    _nightCount = 1;
    _nightStateNumber = 1;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_storageNightCountKey, _nightCount);
    prefs.setDouble(_storageNightStateNumberKey, _nightStateNumber);
    notifyListeners();
  }

  bool isCharacterAwake(Character character) {
    if (!isCharacterAlive(character)) {
      return false;
    }
    if (_nightCount == 0) {
      return false;
    } else if (_nightCount == 1) {
      return character.nightStateNumbersFirstNight.contains(_nightStateNumber);
    } else {
      return character.nightStateNumbersOtherNights.contains(_nightStateNumber);
    }
  }

  Character? getAwakeCharacter(List<Character> gameCharacters) {
    return gameCharacters
        .firstWhereOrNull((element) => isCharacterAwake(element));
  }

  bool isMinionInfo() {
    var firstNight = _nightCount == 1;
    return firstNight && _nightStateNumber >= 2 && _nightStateNumber <= 2.7;
  }

  bool isDemonInfo() {
    var firstNight = _nightCount == 1;
    return firstNight && _nightStateNumber >= 3 && _nightStateNumber <= 3.7;
  }

  String getNightStateHelpText(Character? chracter) {
    if (isMinionInfo()) {
      return "If there are 7 or more players, wake all Minions:\nShow the 'THIS IS THE DEMON' token.\nPoint to the Demon.";
    } else if (isDemonInfo()) {
      return "If there are 7 or more players, wake the Demon:\nShow the 'THESE ARE YOUR MINIONS' token.\nPoint to all Minions.\nShow the 'THESE CHARACTERS ARE NOT IN PLAY' token.\nShow 3 not-in-play good character tokens.";
    }
    if (chracter == null) {
      if (isDust()) {
        return "Check that all eyes are closed.\nSome Travellers & Fabled act.";
      }
      if (isDawn()) {
        return "Wait a few seconds. Call for eyes open & immediately say who died.";
      }
      return "";
    }
    return (chracter.help2.isNotEmpty && nightCount > 1)
        ? chracter.help2
        : chracter.help.isEmpty
            ? chracter.descriptionShort
            : chracter.help;
  }

  String getNightStanteHelpTitle(Character? chracter) {
    if (isMinionInfo()) {
      return "Minion Info";
    } else if (isDemonInfo()) {
      return "Demon Info";
    }
    if (chracter == null) {
      if (isDust()) {
        return "Dusk";
      }
      if (isDawn()) {
        return "Dawn";
      }
      return "";
    }
    return chracter.name;
  }

  bool showNightStateHelpButton() {
    return _nightCount > 0 && _nightStateNumber > 1;
  }

  bool gameIsRunning() {
    return _nightCount > 0;
  }

  bool isDawn() {
    return _nightStateNumber == 0;
  }

  bool isDust() {
    return _nightStateNumber == 1;
  }

  Future<void> previousNightState(List<Character> chracters) async {
    var aliveCharacters =
        chracters.where((element) => isCharacterAlive(element)).toList();
    var validNightStates = aliveCharacters
        .where((character) {
          if (_nightCount == 1) {
            return character.wakeUpAtFirstNight;
          } else {
            return character.wakeUpEveryNight;
          }
        })
        .expand((character) => _nightCount == 1
            ? character.nightStateNumbersFirstNight
                .where((number) => number >= 0)
            : character.nightStateNumbersOtherNights
                .where((number) => number >= 0))
        .toList();
    validNightStates.sort();
    if (_nightCount == 1 && _nightStateNumber == validNightStates[0]) {
      return;
    }
    var previousNightState = validNightStates.lastWhere(
      (number) => number < _nightStateNumber,
      orElse: () {
        previousNight();
        return validNightStates.last;
      },
    );
    _nightStateNumber = previousNightState;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_storageNightStateNumberKey, _nightStateNumber);
    notifyListeners();
  }

  Future<void> nextNightState(List<Character> gameCharacters) async {
    closeMenu();
    if (_nightStateNumber == 0) {
      nextNight();
      return;
    }
    var aliveCharacters =
        gameCharacters.where((element) => isCharacterAlive(element)).toList();
    var validNightStates = aliveCharacters
        .where((character) {
          if (_nightCount == 1) {
            return character.wakeUpAtFirstNight;
          } else {
            return character.wakeUpEveryNight;
          }
        })
        .expand((character) => _nightCount == 1
            ? character.nightStateNumbersFirstNight
            : character.nightStateNumbersOtherNights)
        .toList();
    validNightStates.sort();
    var nextNightState = validNightStates.firstWhere(
      (number) => number > _nightStateNumber,
      orElse: () {
        startDay();
        return -5;
      },
    );
    if (nextNightState == -5) {
      return;
    }
    _nightStateNumber = nextNightState;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_storageNightStateNumberKey, _nightStateNumber);
    notifyListeners();
  }

  Future<void> startDay() async {
    _nightStateNumber = 0;
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble(_storageNightStateNumberKey, _nightStateNumber);
    notifyListeners();
  }

  Future<void> nextNight() async {
    _nightCount++;
    _nightStateNumber = 1;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_storageNightCountKey, _nightCount);
    prefs.setDouble(_storageNightStateNumberKey, _nightStateNumber);
    notifyListeners();
  }

  Future<void> previousNight() async {
    if (_nightCount == 1) {
      return;
    }
    _nightCount--;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(_storageNightCountKey, _nightCount);
    notifyListeners();
  }

  Future<void> addRandomUnusedTokensToRandomCharacters(
      List<Character> characters) async {
    _characterTokens.clear();
    final List<Token> unusedTokens = getAllTokensInGame(characters, characters);
    unusedTokens.shuffle();
    characters.shuffle();
    for (var character in characters) {
      if (unusedTokens.isNotEmpty) {
        var randomInt = Random().nextInt(unusedTokens.length);
        var randomToken = unusedTokens[randomInt];
        _characterTokens[character.id] = [randomToken, randomToken];
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

  List<Token> getAllTokensInGame(
      List<Character> gameCharacters, List<Character> gameCharactersBackup) {
    Set<Character> bothAsSet = {...gameCharacters, ...gameCharactersBackup};
    List<Character> both = bothAsSet.toList();
    initUnusedGameTokens(both);
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
  get showCharactersToPlayers => charactersWhereShownToPlayers;
  get characterSelectionDone => _chracterSelectionDone;

  @override
  void dispose() {
    _scriptService.removeListener(_onScriptSelectionChanged);
    super.dispose();
  }
}
