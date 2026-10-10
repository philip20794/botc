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

  CharacterService() {
    init();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loadGameCharacters(prefs);
    _loadCharacterPositions(prefs);
    _loadGameCharactersBackup(prefs);
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
  }

  void _loadGameCharacters(SharedPreferences prefs) {
    final String? cardListJson = prefs.getString(_storageKey);
    if (cardListJson != null) {
      final List<dynamic> cardList = jsonDecode(cardListJson);
      _gameCharacters.clear();
      _gameCharacters
          .addAll(cardList.map((item) => Character.fromJson(item)).toList());
    }
  }

  void printALlChar() {
    print("printALlChar");
    for (var character in _allCharacters) {
      print(character.name);
      print("wakeuPAtFirstNight: ${character.wakeUpAtFirstNight}");
      print("wakeUpEveryNight: ${character.wakeUpEveryNight}");
    }
  }

  void _loadGameCharactersBackup(SharedPreferences prefs) {
    final String? cardListJson = prefs.getString(_storageKeyBackup);
    if (cardListJson != null) {
      final List<dynamic> cardList = jsonDecode(cardListJson);
      _gameCharactersBackup.clear();
      _gameCharactersBackup
          .addAll(cardList.map((item) => Character.fromJson(item)).toList());
    }
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
    final String allCardsJson =
        await rootBundle.loadString('assets/characters/$localeCode.json');
    final List<dynamic> allCardsList = jsonDecode(allCardsJson);
    _allCharacters.clear();
    _allCharacters
        .addAll(allCardsList.map((item) => Character.fromJson(item)).toList());
    _allCharactersLocaleCode = localeCode;
    notifyListeners();
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
      _gameCharacters[index] =
          Character.fromJson(jsonDecode(jsonEncode(newCharacter)));
      _gameCharacters[index].id += DateTime.timestamp().toString();
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
    resetGameCharactersWithBackup(notify: false);
    _gameCharacters.shuffle();
    putAllFabledCharactersAtTheEnd(notify: false);
    notifyListeners();
  }

  void putAllFabledCharactersAtTheEnd({bool notify = true}) {
    _gameCharacters.sort((a, b) {
      if (a.fraction == Fraction.fabled && b.fraction != Fraction.fabled) {
        return 1;
      } else if (a.fraction != Fraction.fabled &&
          b.fraction == Fraction.fabled) {
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
    _gameCharacters.addAll(_gameCharactersBackup);
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
  }

  void setCharacterPositions(Map<int, Offset> positions) {
    if (_offsetMapsEqual(_characterPositions, positions)) {
      return;
    }
    _characterPositions = Map<int, Offset>.from(positions);
    _saveCharacterPositions();
  }

  void addCharacter(Character character) {
    if (!_gameCharacters.contains(character)) {
      character.id = character.image;
      for (var i = 0; i < character.numberOfExemplars; i++) {
        if (character.variableNumberOfExemplars) {
          character.id = '${character.image}-$i';
        }
        _gameCharacters.add(character);
        _gameCharactersBackup.add(character);
      }
      _saveGameCharacters();
      _saveGameCharactersBackup();
      notifyListeners();
    }
  }

  void removeCharacter(Character character) {
    for (var i = 0; i < character.numberOfExemplars; i++) {
      character = _gameCharacters.firstWhere(
          (element) => element.image == character.image,
          orElse: () => character);
      if (_gameCharacters.contains(character)) {
        character.id = '';
        _gameCharacters.remove(character);
        _gameCharactersBackup.remove(character);
        _saveGameCharacters();
        _saveGameCharactersBackup();
        notifyListeners();
      }
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
    return characters.any((element) => element.image == character.image);
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
          .where((element) => element.fraction != Fraction.fabled)
          .toList();

  List<Character> get gameCharactersBackupWithoutDrunk => _gameCharactersBackup
      .where((element) => element.image != 'Icon_drunk')
      .toList();

  List<Character> get gameCharactersBackupWithoutDrunkAndFabled =>
      gameCharactersBackupWithoutDrunk
          .where((element) => element.fraction != Fraction.fabled)
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
