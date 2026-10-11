import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharacterService extends ChangeNotifier {
  final List<Character> _gameCharacters = [];
  final List<Character> _gameCharactersBackup = [];
  final List<Character> _allCharacters = [];
  Map<int, Offset> _characterPositions = {};
  String? _allCharactersLocaleCode;
  String? _loadingAllCharactersLocaleCode;
  Future<void>? _allCharactersLoadFuture;
  final String _storageKey = 'character_list';
  final String _storageKeyBackup = 'character_list_backup';
  final String _storageKeyPositions = 'character_positions_2';
  bool showInfoButtonOnCharacterSelection = false;
  bool addCharacterToGameWithFractionTownsfolk = false;
  bool addCharacterToGameWithFractionOutsider = false;
  bool addCharacterToGameWithFractionMinion = false;
  bool addCharacterToGameWithFractionDemon = false;
  bool addCharacterToGameWithFractionTraveller = true;
  bool addCharacterToGameWithFractionFabled = false;
  bool addCharacterToGameWithFractionLoric = false;

  CharacterService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final gameCharactersMigrated = _loadGameCharacters(prefs);
    _loadCharacterPositions(prefs);
    final backupMigrated = _loadGameCharactersBackup(prefs);
    if (gameCharactersMigrated) {
      await _saveGameCharacters();
    }
    if (backupMigrated) {
      await _saveGameCharactersBackup();
    }
    notifyListeners();
  }

  Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_storageKeyBackup);
    await prefs.remove(_storageKeyPositions);
    _gameCharacters.clear();
    _gameCharactersBackup.clear();
    _characterPositions.clear();
    notifyListeners();
  }

  void reset() {
    clearGameCards();
  }

  bool everyPlayerGotACharacter() {
    return gameCharactersWithoutDrunk
        .every((element) => element.playerName.isNotEmpty);
  }

  void setAllAddCharacterToGameWithFractionToFalse() {
    addCharacterToGameWithFractionTownsfolk = false;
    addCharacterToGameWithFractionOutsider = false;
    addCharacterToGameWithFractionMinion = false;
    addCharacterToGameWithFractionDemon = false;
    addCharacterToGameWithFractionTraveller = false;
    addCharacterToGameWithFractionFabled = false;
    addCharacterToGameWithFractionLoric = false;
  }

  bool _loadGameCharacters(SharedPreferences prefs) {
    final String? cardListJson = prefs.getString(_storageKey);
    if (cardListJson != null) {
      final List<dynamic> cardList = jsonDecode(cardListJson);
      final identityFieldsMissing = cardList.any((item) =>
          item is Map &&
          (!item.containsKey('id') || _needsRoleIdMigration(item)));
      _gameCharacters.clear();
      _gameCharacters
          .addAll(cardList.map((item) => Character.fromJson(item)).toList());
      final instanceIdsNormalized = _ensureUniqueInstanceIds(_gameCharacters);
      return identityFieldsMissing || instanceIdsNormalized;
    }
    return false;
  }

  void printALlChar() {
    print("printALlChar");
    for (var character in _allCharacters) {
      print(character.name);
      print("wakeuPAtFirstNight: ${character.wakeUpAtFirstNight}");
      print("wakeUpEveryNight: ${character.wakeUpEveryNight}");
    }
  }

  bool _loadGameCharactersBackup(SharedPreferences prefs) {
    final String? cardListJson = prefs.getString(_storageKeyBackup);
    if (cardListJson != null) {
      final List<dynamic> cardList = jsonDecode(cardListJson);
      final identityFieldsMissing = cardList.any((item) =>
          item is Map &&
          (!item.containsKey('id') || _needsRoleIdMigration(item)));
      _gameCharactersBackup.clear();
      _gameCharactersBackup
          .addAll(cardList.map((item) => Character.fromJson(item)).toList());
      final instanceIdsNormalized =
          _ensureUniqueInstanceIds(_gameCharactersBackup);
      return identityFieldsMissing || instanceIdsNormalized;
    }
    return false;
  }

  bool _needsRoleIdMigration(Map item) {
    final image = item['image'];
    final roleId = item['roleId'];
    return image is String &&
        (roleId is! String || Character.hasLegacyRoleId(roleId, image));
  }

  bool _ensureUniqueInstanceIds(List<Character> characters) {
    final usedIds = <String>{};
    var changed = false;

    for (final character in characters) {
      final baseId = character.id.isNotEmpty ? character.id : character.roleId;
      var instanceId = baseId;
      var suffix = 1;
      while (usedIds.contains(instanceId)) {
        instanceId = '$baseId-$suffix';
        suffix++;
      }
      if (character.id != instanceId) {
        character.id = instanceId;
        changed = true;
      }
      usedIds.add(instanceId);
    }

    return changed;
  }

  String _uniqueInstanceId(String preferredId) {
    final usedIds = {
      ..._gameCharacters.map((character) => character.id),
      ..._gameCharactersBackup.map((character) => character.id),
    };
    var instanceId = preferredId;
    var suffix = 1;
    while (usedIds.contains(instanceId)) {
      instanceId = '$preferredId-$suffix';
      suffix++;
    }
    return instanceId;
  }

  void _loadCharacterPositions(SharedPreferences prefs) {
    final String? characterPositionsJson =
        prefs.getString(_storageKeyPositions);
    if (characterPositionsJson != null) {
      final Map<String, dynamic> characterPositionsMap =
          jsonDecode(characterPositionsJson);
      _characterPositions.clear();
      characterPositionsMap.forEach((key, value) {
        final int index = int.parse(key);
        _characterPositions[index] = Offset(
          (value['dx'] as num).toDouble(),
          (value['dy'] as num).toDouble(),
        );
      });
    }
  }

  Future<void> _saveCharacterPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> characterPositionsMap = {};
    _characterPositions.forEach((key, value) {
      characterPositionsMap[key.toString()] = {'dx': value.dx, 'dy': value.dy};
    });
    final String characterPositionsJson = jsonEncode(characterPositionsMap);
    await prefs.setString(_storageKeyPositions, characterPositionsJson);
  }

  void clearCardPositions() {
    _characterPositions.clear();
    _saveCharacterPositions();
  }

  int getFractionCount(Fraction fraction) {
    return _gameCharacters
        .where((character) => character.fraction == fraction)
        .length;
  }

  Future<void> _saveGameCharacters() async {
    final prefs = await SharedPreferences.getInstance();
    final String cardListJson =
        jsonEncode(_gameCharacters.map((card) => card.toJson()).toList());
    await prefs.setString(_storageKey, cardListJson);
  }

  Future<void> _saveGameCharactersBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final String cardListJson =
        jsonEncode(_gameCharactersBackup.map((card) => card.toJson()).toList());
    await prefs.setString(_storageKeyBackup, cardListJson);
  }

  Future<void> loadAllCharactersFromJson(Locale locale) async {
    final localeCode = locale.languageCode;
    if (_allCharacters.isNotEmpty && _allCharactersLocaleCode == localeCode) {
      return;
    }
    final activeLoad = _allCharactersLoadFuture;
    if (activeLoad != null && _loadingAllCharactersLocaleCode == localeCode) {
      return activeLoad;
    }

    _loadingAllCharactersLocaleCode = localeCode;
    final loadFuture = _loadAllCharactersFromJson(localeCode);
    _allCharactersLoadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      _allCharactersLoadFuture = null;
      _loadingAllCharactersLocaleCode = null;
    }
  }

  Future<void> _loadAllCharactersFromJson(String localeCode) async {
    final englishCatalog = await _loadCatalog('en');
    final localizedCatalog =
        localeCode == 'en' ? englishCatalog : await _loadCatalog(localeCode);
    final List<Character> allCharacters = localeCode == 'en'
        ? englishCatalog
            .map((entry) => Character.fromJson(entry as Map<String, dynamic>))
            .toList()
        : mergeLocalizedCatalog(englishCatalog, localizedCatalog);

    _allCharacters.clear();
    _allCharacters.addAll(allCharacters);
    _allCharactersLocaleCode = localeCode;
    notifyListeners();
  }

  /// Returns the complete English catalog without changing the active locale
  /// or any persisted game state.
  Future<List<Character>> loadCanonicalCharacterCatalog() async {
    final englishCatalog = await _loadCatalog('en');
    return englishCatalog
        .map((entry) => Character.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<List<dynamic>> _loadCatalog(String localeCode) async {
    final catalogJson =
        await rootBundle.loadString('assets/characters/$localeCode.json');
    return jsonDecode(catalogJson) as List<dynamic>;
  }

  /// Builds a complete localized catalog without allowing localization data to
  /// change role identity or game-relevant metadata.
  static List<Character> mergeLocalizedCatalog(
    List<dynamic> englishCatalog,
    List<dynamic> localizedCatalog,
  ) {
    final localizedByRoleId = <String, Map<String, dynamic>>{
      for (final entry in localizedCatalog)
        _roleIdFromCatalogJson(entry as Map<String, dynamic>): entry,
    };

    return englishCatalog.map((entry) {
      final english = entry as Map<String, dynamic>;
      final localized = localizedByRoleId[_roleIdFromCatalogJson(english)];
      return Character.fromJson(
        localized == null
            ? english
            : _mergeLocalizedCharacter(english, localized),
      );
    }).toList();
  }

  static const _requiredLocalizedTextFields = <String>{
    'name',
    'descriptionShort',
    'descriptionLong',
    'howToRun',
  };

  static const _optionalLocalizedTextFields = <String>{
    'help',
    'help2',
  };

  static const _optionalLocalizedListFields = <String>{
    'tipsAndTricks',
    'bluffs',
  };

  static Map<String, dynamic> _mergeLocalizedCharacter(
    Map<String, dynamic> english,
    Map<String, dynamic> localized,
  ) {
    final merged = Map<String, dynamic>.from(english);

    for (final field in _requiredLocalizedTextFields) {
      final value = localized[field];
      if (value is String && value.trim().isNotEmpty) {
        merged[field] = value;
      }
    }
    for (final field in _optionalLocalizedTextFields) {
      final value = localized[field];
      if (value is String) {
        merged[field] = value;
      }
    }
    for (final field in _optionalLocalizedListFields) {
      final value = localized[field];
      if (value is List<dynamic>) {
        merged[field] = value;
      }
    }

    merged['tokens'] = _mergeLocalizedTokens(
      english['tokens'] as List<dynamic>,
      localized['tokens'],
    );
    return merged;
  }

  static List<Map<String, dynamic>> _mergeLocalizedTokens(
    List<dynamic> englishTokens,
    dynamic localizedTokens,
  ) {
    if (localizedTokens is! List<dynamic>) {
      return englishTokens
          .map((token) => Map<String, dynamic>.from(token as Map))
          .toList();
    }

    return List.generate(englishTokens.length, (index) {
      final mergedToken =
          Map<String, dynamic>.from(englishTokens[index] as Map);
      if (index >= localizedTokens.length || localizedTokens[index] is! Map) {
        return mergedToken;
      }
      final localizedName = (localizedTokens[index] as Map)['name'];
      if (localizedName is String && localizedName.trim().isNotEmpty) {
        mergedToken['name'] = localizedName;
      }
      return mergedToken;
    });
  }

  static String _roleIdFromCatalogJson(Map<String, dynamic> character) {
    return Character.normalizedRoleId(
      character['image'] as String,
      character['roleId'] as String?,
    );
  }

  int getCharacterIndex(Character character) {
    return gameCharactersWithoutDrunkAndFabled.indexOf(character);
  }

  void setNameOfCharacter(Character character, String name) {
    final index = _gameCharacters.indexOf(character);
    if (index != -1 && _gameCharacters[index].playerName != name) {
      _gameCharacters[index].playerName = name;
      _saveGameCharacters();
      notifyListeners();
    }
  }

  void syncPlayerNames(List<String> playerNames) {
    var changed = false;
    final assignableCharacters = gameCharactersWithoutDrunkAndFabled;

    for (var i = 0; i < assignableCharacters.length; i++) {
      if (playerNames.length <= i) {
        break;
      }
      final character = assignableCharacters[i];
      final playerName = playerNames[i];
      if (character.playerName != playerName) {
        character.playerName = playerName;
        changed = true;
      }
    }

    if (changed) {
      _saveGameCharacters();
      notifyListeners();
    }
  }

  String changeCharacter(Character oldCharacter, Character newCharacter) {
    final index = _gameCharacters.indexOf(oldCharacter);
    if (index != -1) {
      final replacementId = _uniqueInstanceId(
          '${newCharacter.roleId}-${DateTime.timestamp().microsecondsSinceEpoch}');
      _gameCharacters[index] = newCharacter.copyWith(id: replacementId);
      _gameCharacters[index].playerName = oldCharacter.playerName;
      _saveGameCharacters();
      notifyListeners();
      return _gameCharacters[index].id;
    }
    return "";
  }

  void flipCharacter(Character character) {
    final char = _gameCharacters.firstWhere(
        (element) => element.id == character.id,
        orElse: () => character);
    char.upsideDown = !char.upsideDown;
    _saveGameCharacters();
    notifyListeners();
  }

  void shuffelCharacters() {
    _clearPlayerNamesOnGameCards();
    _saveGameCharactersBackup();
    resetGameCharactersWithBackup(notify: false);
    _gameCharacters.shuffle();
    putAllFabledCharactersAtTheEnd(notify: false);
    notifyListeners();
  }

  void putAllFabledCharactersAtTheEnd({bool notify = true}) {
    _gameCharacters.sort((a, b) {
      final aIsSpecial =
          a.fraction == Fraction.fabled || a.fraction == Fraction.loric;
      final bIsSpecial =
          b.fraction == Fraction.fabled || b.fraction == Fraction.loric;
      if (aIsSpecial && !bIsSpecial) {
        return 1;
      } else if (!aIsSpecial && bIsSpecial) {
        return -1;
      } else {
        return 0;
      }
    });
    if (notify) {
      notifyListeners();
    }
  }

  void endGame() {
    _clearPlayerNamesOnGameCards();
    _saveGameCharactersBackup();
    resetGameCharactersWithBackup();
  }

  void _clearPlayerNamesOnGameCards() {
    for (var character in _gameCharacters) {
      character.playerName = '';
      character.upsideDown = false;
    }
    for (var character in _gameCharactersBackup) {
      character.playerName = '';
      character.upsideDown = false;
    }
  }

  void resetGameCharactersWithBackup({bool notify = true}) {
    _gameCharacters.clear();
    _gameCharacters
        .addAll(_gameCharactersBackup.map((character) => character.copyWith()));
    _saveGameCharacters();
    if (notify) {
      notifyListeners();
    }
  }

  void setCharacterPosition(int pos, Offset position) {
    if (_characterPositions[pos] == position) {
      return;
    }
    _characterPositions[pos] = position;
    _saveCharacterPositions();
    notifyListeners();
  }

  void setCharacterPositions(Map<int, Offset> positions) {
    if (_offsetMapsEqual(_characterPositions, positions)) {
      return;
    }
    _characterPositions = Map<int, Offset>.from(positions);
    _saveCharacterPositions();
    notifyListeners();
  }

  void addCharacter(Character character) {
    if (!containsCharacter(_gameCharacters, character)) {
      for (var i = 0; i < character.numberOfExemplars; i++) {
        final hasMultipleInstances = character.numberOfExemplars > 1;
        final preferredId =
            hasMultipleInstances ? '${character.roleId}-$i' : character.roleId;
        final gameCharacter =
            character.copyWith(id: _uniqueInstanceId(preferredId));
        _gameCharacters.add(gameCharacter);
        _gameCharactersBackup.add(gameCharacter.copyWith());
      }
      _saveGameCharacters();
      _saveGameCharactersBackup();
      notifyListeners();
    }
  }

  void removeCharacter(Character character) {
    final gameLength = _gameCharacters.length;
    final backupLength = _gameCharactersBackup.length;
    _gameCharacters.removeWhere(
        (gameCharacter) => gameCharacter.roleId == character.roleId);
    _gameCharactersBackup.removeWhere(
        (gameCharacter) => gameCharacter.roleId == character.roleId);
    if (_gameCharacters.length != gameLength ||
        _gameCharactersBackup.length != backupLength) {
      _saveGameCharacters();
      _saveGameCharactersBackup();
      notifyListeners();
    }
  }

  void clearGameCards() {
    _gameCharacters.clear();
    _gameCharactersBackup.clear();
    _saveGameCharacters();
    _saveGameCharactersBackup();
    notifyListeners();
  }

  List<Character> getRandomCharacter(int numberOfCharacters) {
    final List<Character> characters = [];
    var allCharactersCopy = List<Character>.from(_allCharacters
        .where((element) => element.image != 'Icon_drunk')
        .toList());

    if (allCharactersCopy.isNotEmpty) {
      for (int i = 0; i < numberOfCharacters; i++) {
        final int randomIndex = Random().nextInt(allCharactersCopy.length);
        final Character randomCharacter = allCharactersCopy[randomIndex];
        characters.add(randomCharacter);
        allCharactersCopy.remove(randomCharacter);
      }
    }

    return characters;
  }

  List<Character> getAllCharactersOfGameset(Gameset selectedGameset) {
    return _allCharacters
        .where((element) => element.gameset.contains(selectedGameset))
        .toList();
  }

  bool containsCharacter(List<Character> characters, Character character) {
    return characters.any((element) => element.roleId == character.roleId);
  }

  Character getCharacterByImage(String image) {
    return _allCharacters.firstWhere((element) => element.image == image);
  }

  List<Character> get gameCharacters => _gameCharacters;

  List<Character> get gameCharactersWithoutDrunk => _gameCharacters
      .where((element) => element.image != 'Icon_drunk')
      .toList();

  List<Character> get gameCharactersWithoutDrunkAndFabled =>
      gameCharactersWithoutDrunk
          .where((element) =>
              element.fraction != Fraction.fabled &&
              element.fraction != Fraction.loric)
          .toList();

  List<Character> get gameCharactersBackupWithoutDrunk => _gameCharactersBackup
      .where((element) => element.image != 'Icon_drunk')
      .toList();

  List<Character> get gameCharactersBackupWithoutDrunkAndFabled =>
      gameCharactersBackupWithoutDrunk
          .where((element) =>
              element.fraction != Fraction.fabled &&
              element.fraction != Fraction.loric)
          .toList();

  List<Character> get gameCharactersBackup => _gameCharactersBackup;

  List<Character> get allCharacters => _allCharacters;

  Map<int, Offset> get characterPositions => _characterPositions;

  bool _offsetMapsEqual(Map<int, Offset> a, Map<int, Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}
