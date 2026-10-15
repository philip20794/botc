import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/active_night_chronicle_input.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/models/game_record_capture.dart';
import 'package:blood_on_the_clocktower/models/quick_flow.dart';
import 'package:blood_on_the_clocktower/models/quick_flow_runtime.dart';
import 'package:blood_on_the_clocktower/models/token.dart';
import 'package:blood_on_the_clocktower/services/night_order_service.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_record_upload_queue.dart';
import 'package:blood_on_the_clocktower/services/game_record_validator.dart';
import 'package:blood_on_the_clocktower/services/quick_flow_interpreter.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameStateService extends ChangeNotifier {
  static const _quickFlowInterpreter = QuickFlowInterpreter();
  final ScriptService _scriptService;
  final NightOrderService _nightOrderService;
  final ChronicleService? _chronicleService;
  final GameRecordUploadQueue _gameRecordUploadQueue;
  final DateTime Function() _now;
  Future<void>? _endGameOperation;
  late final Future<void> ready;
  bool _isLocked = false;
  bool _forceUpdateLayout = false;
  final String _storageIsLockedKey = 'is_locked';
  final Map<String, List<Token>> _characterTokens = {};
  final Map<String, bool> _characterAliveState = {};
  final Set<String> _apparentlyDeadCharacterIds = {};
  int? _lastReportedDeathDay;
  List<Token> unsedGameTokens = [];
  List<String> playerNames = [];
  int _nightCount = -1;
  DateTime? _gameStartedAt;
  DateTime? _dayStartedAt;
  GameRecordCapture? _activeGameRecordCapture;
  GameRecordCapture? _lastGameRecordCapture;
  GameRecord? _lastCompletedGameRecord;
  bool initIsDone = false;
  bool _chracterSelectionDone = false;
  double _nightStateNumber = 0;
  String? _currentNightStepId;
  double? _legacyNightStateNumber;
  bool charactersWhereShownToPlayers = false;
  final String _storageCharacterTokensKey = 'character_tokens';
  final String _storageCharacterAliveStateKey = 'character_alive_state';
  static const String _storageApparentDeathStateKey =
      'character_apparent_death_state';
  static const String _storageLastReportedDeathDayKey =
      'last_reported_death_day';
  final String _storagePlayerNamesKey = 'player_names';
  final String _storageGamesetKey = 'gameset';
  final String _storageNightCountKey = 'night_count';
  final String _storageNightStateNumberKey = 'night_state_number';
  static const String _storageNightStepIdKey = 'night_step_id';
  static const String _storageGameStartedAtKey = 'game_started_at';
  static const String _storageDayStartedAtKey = 'day_started_at';
  static const String _storageGameRecordCaptureKey = 'game_record_capture_v1';
  static const String _storageLastGameRecordKey = 'game_record_last_v1';
  static const String _storageLastGameRecordCaptureKey =
      'game_record_last_capture_v1';
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
  final Set<String> _quickFlowSkippedInfo = {};
  final Set<String> _quickFlowCompletedSteps = {};
  final Map<String, _QuickFlowNightBaseline> _quickFlowNightBaselines = {};
  String? _activeQuickFlowContextKey;
  String? _activeQuickFlowStepKey;
  int? _openMenuId;
  String? openTokenMenuId;

  GameStateService({
    ScriptService? scriptService,
    NightOrderService? nightOrderService,
    ChronicleService? chronicleService,
    GameRecordUploadQueue? gameRecordUploadQueue,
    DateTime Function()? now,
  })  : _scriptService = scriptService ?? ScriptService(),
        _nightOrderService = nightOrderService ?? NightOrderService(),
        _chronicleService = chronicleService,
        _gameRecordUploadQueue =
            gameRecordUploadQueue ?? GameRecordUploadQueue(),
        _now = now ?? DateTime.now {
    _scriptService.addListener(_onScriptSelectionChanged);
    ready = init();
  }

  void _onScriptSelectionChanged() => notifyListeners();

  Future<void> init() async {
    await _scriptService.ready;
    await _gameRecordUploadQueue.ready;
    final prefs = await SharedPreferences.getInstance();
    _loadIsLocked(prefs);
    _loadCharacterTokens(prefs);
    _loadCharacterAliveState(prefs);
    _loadApparentDeathState(prefs);
    _loadPlayerNames(prefs);
    _loadNightCount(prefs);
    _currentNightStepId = prefs.getString(_storageNightStepIdKey);
    _loadGameStartedAt(prefs);
    _loadGameRecordState(prefs);
    if (gameIsRunning() && _gameStartedAt == null) {
      await _startGameTimer(startedAt: _activeGameRecordCapture?.startedAt);
    }
    _loadDayStartedAt(prefs);
    if (_currentNightStepId == 'day' && _dayStartedAt == null) {
      final capturedDayStart = _activeGameRecordCapture?.phases
          .lastWhereOrNull(
              (phase) => phase.isOpen && phase.type == GameRecordPhaseType.day)
          ?.startedAt;
      await _startDayTimer(startedAt: capturedDayStart);
    }
    _loadNightStateNumber(prefs);
    _loadShowCharactersToPlayers(prefs);
    _loadChracterSelectionDone(prefs);
    _loadDemonBluffRoleIds(prefs);
    _loadQuickFlowState(prefs);
    notifyListeners();
  }

  Future<void> factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_storageIsLockedKey),
      prefs.remove(_storageCharacterTokensKey),
      prefs.remove(_storageCharacterAliveStateKey),
      prefs.remove(_storageApparentDeathStateKey),
      prefs.remove(_storageLastReportedDeathDayKey),
      prefs.remove(_storagePlayerNamesKey),
      prefs.remove(_storageGamesetKey),
      prefs.remove(_storageNightCountKey),
      prefs.remove(_storageNightStateNumberKey),
      prefs.remove(_storageNightStepIdKey),
      prefs.remove(_storageGameStartedAtKey),
      prefs.remove(_storageDayStartedAtKey),
      prefs.remove(_storageGameRecordCaptureKey),
      prefs.remove(_storageLastGameRecordKey),
      prefs.remove(_storageLastGameRecordCaptureKey),
      prefs.remove(_storageShowCharactersToPlayersKey),
      prefs.remove(_chracterSelectionDoneKey),
      prefs.remove(_storageDemonBluffRoleIdsKey),
      prefs.remove(_storageQuickFlowStateKey),
    ]);
    _isLocked = false;
    _characterTokens.clear();
    _characterAliveState.clear();
    _apparentlyDeadCharacterIds.clear();
    _lastReportedDeathDay = null;
    playerNames.clear();
    _nightCount = -1;
    _nightStateNumber = 0;
    _currentNightStepId = null;
    _gameStartedAt = null;
    _dayStartedAt = null;
    _activeGameRecordCapture = null;
    _lastGameRecordCapture = null;
    _lastCompletedGameRecord = null;
    _demonBluffRoleIds = [];
    _clearQuickFlowRuntime();
    await _chronicleService?.factoryReset();
    await init();
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
      final skippedInfo = json['skippedInfo'];
      if (skippedInfo is List) {
        _quickFlowSkippedInfo.addAll(skippedInfo.whereType<String>());
      }
      final completedSteps = json['completedSteps'];
      if (completedSteps is List) {
        _quickFlowCompletedSteps.addAll(completedSteps.whereType<String>());
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
        'skippedInfo': _quickFlowSkippedInfo.toList(),
        'completedSteps': _quickFlowCompletedSteps.toList(),
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
    _quickFlowSkippedInfo.clear();
    _quickFlowCompletedSteps.clear();
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

  Future<void> _saveApparentDeathState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageApparentDeathStateKey,
      _apparentlyDeadCharacterIds.toList(),
    );
    if (_lastReportedDeathDay == null) {
      await prefs.remove(_storageLastReportedDeathDayKey);
    } else {
      await prefs.setInt(
          _storageLastReportedDeathDayKey, _lastReportedDeathDay!);
    }
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
    if (_apparentlyDeadCharacterIds.remove(characterA.id)) {
      _apparentlyDeadCharacterIds.add(eid);
    }
    final capture = _activeGameRecordCapture;
    if (capture != null) {
      final players = List<GameRecordCapturePlayer>.from(capture.players);
      final playerIndex = players.indexWhere(
          (player) => player.currentCharacterInstanceId == characterA.id);
      if (playerIndex >= 0) {
        players[playerIndex] = players[playerIndex].copyWith(
          currentCharacterInstanceId: eid,
        );
        _activeGameRecordCapture = capture.copyWith(players: players);
      }
    }
    await Future.wait([
      _saveCharacterTokens(),
      _saveCharacterAliveState(),
      _saveApparentDeathState(),
      if (_activeGameRecordCapture != null) _saveActiveGameRecordCapture(),
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

  void _loadDayStartedAt(SharedPreferences prefs) {
    if (_currentNightStepId != 'day') {
      _dayStartedAt = null;
      return;
    }
    final rawValue = prefs.getString(_storageDayStartedAtKey);
    _dayStartedAt = rawValue == null ? null : DateTime.tryParse(rawValue);
  }

  void _loadGameStartedAt(SharedPreferences prefs) {
    if (!gameIsRunning()) {
      _gameStartedAt = null;
      return;
    }
    final rawValue = prefs.getString(_storageGameStartedAtKey);
    _gameStartedAt = rawValue == null ? null : DateTime.tryParse(rawValue);
  }

  Future<void> _startGameTimer({DateTime? startedAt}) async {
    _gameStartedAt = startedAt ?? _now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageGameStartedAtKey,
      _gameStartedAt!.toIso8601String(),
    );
  }

  Future<void> _clearGameTimer() async {
    _gameStartedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageGameStartedAtKey);
  }

  Future<void> _startDayTimer({DateTime? startedAt}) async {
    _dayStartedAt = startedAt ?? _now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageDayStartedAtKey,
      _dayStartedAt!.toIso8601String(),
    );
  }

  Future<void> _clearDayTimer() async {
    _dayStartedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageDayStartedAtKey);
  }

  void _loadGameRecordState(SharedPreferences prefs) {
    GameRecordCapture? decodeCapture(String? raw) {
      if (raw == null) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return null;
        final capture = GameRecordCapture.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return capture.schemaVersion == GameRecordCapture.currentSchemaVersion
            ? capture
            : null;
      } catch (_) {
        return null;
      }
    }

    _activeGameRecordCapture =
        decodeCapture(prefs.getString(_storageGameRecordCaptureKey));
    _lastGameRecordCapture =
        decodeCapture(prefs.getString(_storageLastGameRecordCaptureKey));
    final rawRecord = prefs.getString(_storageLastGameRecordKey);
    if (rawRecord == null) return;
    try {
      final decoded = jsonDecode(rawRecord);
      if (decoded is Map) {
        final record = GameRecord.fromJson(Map<String, dynamic>.from(decoded));
        if (const GameRecordValidator().validate(record).isValid) {
          _lastCompletedGameRecord = record;
        }
      }
    } catch (_) {
      _lastCompletedGameRecord = null;
    }
  }

  Future<void> _saveActiveGameRecordCapture() async {
    final capture = _activeGameRecordCapture;
    if (capture == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageGameRecordCaptureKey,
      jsonEncode(capture.toJson()),
    );
  }

  String _createGameRecordId(DateTime startedAt) {
    final source =
        '${startedAt.microsecondsSinceEpoch}:${_now().microsecondsSinceEpoch}';
    return 'game_${sha256.convert(utf8.encode(source)).toString().substring(0, 24)}';
  }

  String _opaqueId(String prefix, String source) =>
      '${prefix}_${sha256.convert(utf8.encode(source)).toString().substring(0, 24)}';

  GameTeam? _teamForFraction(Fraction fraction) => switch (fraction) {
        Fraction.townsfolk || Fraction.outsider => GameTeam.good,
        Fraction.minion || Fraction.demon => GameTeam.evil,
        Fraction.traveller || Fraction.fabled || Fraction.loric => null,
      };

  Future<void> _beginGameRecordCapture({
    required String gameId,
    required DateTime startedAt,
    required List<Character> visiblePlayers,
    required List<Character> setupCharacters,
    required List<Character> scriptCatalog,
    required GameRecordPhaseType initialPhase,
  }) async {
    final roster = visiblePlayers
        .where((character) =>
            character.fraction != Fraction.fabled &&
            character.fraction != Fraction.loric &&
            character.roleId != 'drunk')
        .toList(growable: false);
    var players = <GameRecordCapturePlayer>[
      for (var position = 0; position < roster.length; position++)
        GameRecordCapturePlayer(
          anonymizedPlayerId: _opaqueId(
            'player',
            '$gameId:$position:${roster[position].id}',
          ),
          position: position,
          initialCharacterInstanceId: roster[position].id,
          currentCharacterInstanceId: roster[position].id,
          actualStartRoleId: roster[position].roleId,
          displayedStartRoleId: roster[position].roleId,
          startTeam: _teamForFraction(roster[position].fraction),
          currentRoleId: roster[position].roleId,
          currentTeam: _teamForFraction(roster[position].fraction),
        ),
    ];
    final phase = GameRecordCapturedPhase(
      phaseId: _opaqueId('phase', '$gameId:${initialPhase.name}:1'),
      type: initialPhase,
      round: 1,
      startedAt: startedAt,
    );
    _activeGameRecordCapture = GameRecordCapture(
      gameId: gameId,
      startedAt: startedAt,
      script: _scriptService.gameRecordSnapshot(scriptCatalog),
      players: players,
      phases: [phase],
    );

    // Setup reminders can already be assigned before the actual game starts.
    for (final entry in _characterTokens.entries) {
      final target = setupCharacters.firstWhereOrNull(
        (character) => character.id == entry.key,
      );
      if (target == null) continue;
      for (final token in entry.value) {
        players = await _applyActualStartRoleMarker(
          allCharacters: setupCharacters,
          target: target,
          token: token,
          persist: false,
        );
      }
    }
    if (players.isNotEmpty &&
        !identical(players, _activeGameRecordCapture!.players)) {
      _activeGameRecordCapture = _activeGameRecordCapture!.copyWith(
        players: players,
      );
    }
    await _saveActiveGameRecordCapture();
  }

  Future<List<GameRecordCapturePlayer>> _applyActualStartRoleMarker({
    required List<Character> allCharacters,
    required Character target,
    required Token token,
    bool persist = true,
  }) async {
    final capture = _activeGameRecordCapture;
    if (capture == null ||
        !token.needsSetup ||
        token.quickId != 'is_the_drunk') {
      return capture?.players ?? const [];
    }
    final owner = allCharacters.firstWhereOrNull(
      (character) => character.id == token.ownerRoleInstanceId,
    );
    if (owner != null && owner.roleId != 'drunk') return capture.players;
    final index = capture.players.indexWhere((player) =>
        player.currentCharacterInstanceId == target.id ||
        player.initialCharacterInstanceId == target.id);
    if (index < 0) return capture.players;
    final players = capture.players.map((player) {
      if (player.actualStartRoleId != 'drunk') return player;
      final displayedRole = allCharacters.firstWhereOrNull(
        (character) => character.roleId == player.displayedStartRoleId,
      );
      return player.copyWith(
        actualStartRoleId: player.displayedStartRoleId,
        startTeam: displayedRole == null
            ? GameTeam.good
            : _teamForFraction(displayedRole.fraction),
      );
    }).toList(growable: false);
    players[index] = players[index].copyWith(
      actualStartRoleId: owner?.roleId ?? 'drunk',
      startTeam:
          owner == null ? GameTeam.good : _teamForFraction(owner.fraction),
    );
    _activeGameRecordCapture = capture.copyWith(players: players);
    if (persist) await _saveActiveGameRecordCapture();
    return players;
  }

  Future<bool> _transitionGameRecordPhase(
    GameRecordPhaseType type,
    int round,
    DateTime transitionAt,
  ) async {
    final capture = _activeGameRecordCapture;
    if (capture == null || capture.endedAt != null || capture.phases.isEmpty) {
      return false;
    }
    final phases = List<GameRecordCapturedPhase>.from(capture.phases);
    final active = phases.last;
    if (!active.isOpen || (active.type == type && active.round == round)) {
      return false;
    }
    final validForwardTransition = active.type == GameRecordPhaseType.night &&
            type == GameRecordPhaseType.day &&
            round == active.round ||
        active.type == GameRecordPhaseType.day &&
            type == GameRecordPhaseType.night &&
            round == active.round + 1;
    if (!validForwardTransition || transitionAt.isBefore(active.startedAt)) {
      return false;
    }
    phases[phases.length - 1] = active.close(transitionAt);
    phases.add(GameRecordCapturedPhase(
      phaseId: _opaqueId('phase', '${capture.gameId}:${type.name}:$round'),
      type: type,
      round: round,
      startedAt: transitionAt,
    ));
    _activeGameRecordCapture = capture.copyWith(phases: phases);
    await _saveActiveGameRecordCapture();
    return true;
  }

  GameRecordCapture? _finalGameRecordCapture({
    required DateTime endedAt,
    required String? winningTeam,
    required List<Character> gameCharacters,
  }) {
    final capture = _activeGameRecordCapture;
    if (capture == null) return null;
    final phases = List<GameRecordCapturedPhase>.from(capture.phases);
    if (phases.isNotEmpty && phases.last.isOpen) {
      phases[phases.length - 1] = phases.last.close(endedAt);
    }
    final roster = gameCharacters
        .where((character) =>
            character.fraction != Fraction.fabled &&
            character.fraction != Fraction.loric &&
            character.roleId != 'drunk')
        .toList(growable: false);
    final players = <GameRecordCapturePlayer>[
      for (final player in capture.players)
        if (player.position < roster.length)
          player.copyWith(
            currentCharacterInstanceId: roster[player.position].id,
            currentRoleId: roster[player.position].roleId,
            currentTeam: _teamForFraction(roster[player.position].fraction),
          )
        else
          player,
    ];
    final winner = GameTeam.values.firstWhereOrNull(
      (team) => team.name == winningTeam,
    );
    return capture.copyWith(
      phases: phases,
      players: players,
      endedAt:
          endedAt.isBefore(capture.startedAt) ? capture.startedAt : endedAt,
      winnerTeam: winner,
    );
  }

  GameRecord? _completeGameRecordFromChronicle(
    GameRecordCapture? capture,
    ChronicleLog? chronicle,
  ) {
    final endedAt = capture?.endedAt;
    final winner = capture?.winnerTeam;
    if (capture == null || endedAt == null || winner == null) return null;
    final players = <GameRecordPlayer>[];
    for (final player in capture.players) {
      final actualStartRoleId = player.actualStartRoleId;
      final startTeam = player.startTeam;
      final endTeam = player.currentTeam;
      if (actualStartRoleId == null || startTeam == null || endTeam == null) {
        return null;
      }
      players.add(GameRecordPlayer(
        anonymizedPlayerId: player.anonymizedPlayerId,
        position: player.position,
        actualStartRoleId: actualStartRoleId,
        displayedStartRoleId: player.displayedStartRoleId,
        startTeam: startTeam,
        endRoleId: player.currentRoleId,
        endTeam: endTeam,
      ));
    }
    final phases = capture.phases
        .map((phase) => phase.toGameRecordPhase())
        .whereType<GameRecordPhase>()
        .toList(growable: false);
    final record = GameRecord(
      gameId: capture.gameId,
      startedAt: capture.startedAt,
      endedAt: endedAt,
      totalDuration: endedAt.difference(capture.startedAt),
      playerCount: players.length,
      winnerTeam: winner,
      script: capture.script,
      players: players,
      phases: phases,
      chronicleEvents: _gameRecordChronicleEvents(
        chronicle,
        capture,
      ),
    );
    if (!const GameRecordValidator().validate(record).isValid) return null;
    return record;
  }

  List<GameRecordChronicleEvent> _gameRecordChronicleEvents(
    ChronicleLog? chronicle,
    GameRecordCapture capture,
  ) {
    final endedAt = capture.endedAt;
    if (chronicle == null || endedAt == null) return const [];
    final playerByCharacterId = <String, String>{
      for (final player in capture.players)
        player.initialCharacterInstanceId: player.anonymizedPlayerId,
    };
    final validPhaseKeys = capture.phases
        .where((phase) => phase.endedAt != null)
        .map((phase) => '${phase.type.name}:${phase.round}')
        .toSet();
    final result = <GameRecordChronicleEvent>[];
    for (final event in chronicle.events) {
      if (event.timestamp.isBefore(capture.startedAt) ||
          event.timestamp.isAfter(endedAt)) {
        continue;
      }
      final actorId = event.character == null
          ? null
          : playerByCharacterId[event.character!.characterId];
      if (event.type == ChronicleEventType.characterChanged &&
          actorId != null &&
          event.targets.isNotEmpty) {
        playerByCharacterId[event.targets.first.characterId] = actorId;
      }
      final phase = switch (event.phase) {
        ChroniclePhase.setup => GameRecordEventPhase.setup,
        ChroniclePhase.night => GameRecordEventPhase.night,
        ChroniclePhase.day => GameRecordEventPhase.day,
      };
      if (phase != GameRecordEventPhase.setup &&
          !validPhaseKeys.contains('${phase.name}:${event.round}')) {
        continue;
      }
      final targets = event.targets
          .map((target) => playerByCharacterId[target.characterId])
          .whereType<String>()
          .toSet()
          .toList(growable: false);
      result.add(GameRecordChronicleEvent(
        eventId: _opaqueId('event', '${capture.gameId}:${event.id}'),
        occurredAt: event.timestamp,
        type: GameRecordChronicleEventType.values.firstWhere(
          (type) => type.name == event.type.name,
        ),
        phase: phase,
        round: phase == GameRecordEventPhase.setup ? 0 : event.round,
        actorPlayerId: actorId,
        targetPlayerIds: targets,
        data: _structuredEventData(event, playerByCharacterId),
      ));
    }
    return result;
  }

  GameRecordEventData _structuredEventData(
    ChronicleEvent event,
    Map<String, String> playerByCharacterId,
  ) {
    final flags = <String, bool>{};
    final numbers = <String, int>{};
    final playerIds = <String, List<String>>{};
    final roleIds = <String, List<String>>{};
    final tokenIds = <String, List<String>>{};
    final alive = event.details['alive'];
    if (alive is bool) flags['alive'] = alive;
    if (event.character != null && event.character!.roleId.isNotEmpty) {
      roleIds['actorRoles'] = [event.character!.roleId];
    }
    final targetRoles = event.targets
        .map((target) => target.roleId)
        .where((roleId) => roleId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (targetRoles.isNotEmpty) roleIds['targetRoles'] = targetRoles;
    final quickId = event.details['quickId'];
    if (quickId is String &&
        RegExp(r'^[a-z0-9][a-z0-9_-]{0,127}$').hasMatch(quickId)) {
      tokenIds['reminders'] = [quickId];
    }

    void absorbValues(Map<dynamic, dynamic> values) {
      for (final entry in values.entries) {
        final key = _safeEventDataKey(entry.key.toString());
        if (key == null) continue;
        final value = entry.value;
        if (value is bool) {
          flags[key] = value;
        } else if (value is int) {
          numbers[key] = value;
        } else if (value is num && value == value.roundToDouble()) {
          numbers[key] = value.toInt();
        } else {
          final ids = _playerIdsFromValue(value, playerByCharacterId);
          if (ids.isNotEmpty) playerIds[key] = ids;
        }
      }
    }

    absorbValues(event.details);
    for (final entry in event.informationEntries) {
      final values = entry['values'];
      if (values is Map) absorbValues(values);
    }
    return GameRecordEventData(
      flags: flags,
      numbers: numbers,
      roleIds: roleIds,
      playerIds: playerIds,
      tokenIds: tokenIds,
    );
  }

  String? _safeEventDataKey(String source) {
    final cleaned = source.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
    if (cleaned.isEmpty) return null;
    final prefixed =
        RegExp(r'^[A-Za-z]').hasMatch(cleaned) ? cleaned : 'value_$cleaned';
    final result = '${prefixed[0].toLowerCase()}${prefixed.substring(1)}';
    return result.length > 64 ? result.substring(0, 64) : result;
  }

  List<String> _playerIdsFromValue(
    dynamic value,
    Map<String, String> playerByCharacterId,
  ) {
    final ids = <String>{};
    void visit(dynamic item) {
      if (item is Map) {
        final characterId = item['characterId'];
        if (characterId is String) {
          final playerId = playerByCharacterId[characterId];
          if (playerId != null) ids.add(playerId);
        }
      } else if (item is List) {
        for (final child in item) {
          visit(child);
        }
      }
    }

    visit(value);
    return ids.toList(growable: false);
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

  void _loadApparentDeathState(SharedPreferences prefs) {
    _apparentlyDeadCharacterIds
      ..clear()
      ..addAll(prefs.getStringList(_storageApparentDeathStateKey) ?? const []);
    _lastReportedDeathDay = prefs.getInt(_storageLastReportedDeathDayKey);
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

  Future<void> addPlayerName(String playerName) async {
    if (playerName.isEmpty) {
      return;
    }
    playerNames.add(playerName); // _playerNames bleibt List<String>
    final prefs = await SharedPreferences.getInstance();
    final String data =
        jsonEncode(playerNames); // Liste von Strings wird gespeichert
    await prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  Future<void> removePlayerName(String playerName) async {
    if (!playerNames.contains(playerName)) {
      return;
    }
    playerNames.remove(playerName);
    final prefs = await SharedPreferences.getInstance();
    final String data =
        jsonEncode(playerNames); // JSON enthält Liste von Strings
    await prefs.setString(_storagePlayerNamesKey, data);
    notifyListeners();
  }

  Future<void> clearAllPlayerNames() async {
    if (playerNames.isEmpty) {
      return;
    }
    playerNames.clear();
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(playerNames);
    await prefs.setString(_storagePlayerNamesKey, data);
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

  Future<void> endGame({
    String? winningTeam,
    List<Character> gameCharacters = const [],
    CharacterService? characterService,
  }) {
    final activeOperation = _endGameOperation;
    if (activeOperation != null) return activeOperation;
    final operation = _guardedEndGame(
      winningTeam: winningTeam,
      gameCharacters: gameCharacters,
      characterService: characterService,
    );
    _endGameOperation = operation;
    return operation;
  }

  Future<void> _guardedEndGame({
    required String? winningTeam,
    required List<Character> gameCharacters,
    required CharacterService? characterService,
  }) async {
    try {
      await _endGameOnce(
        winningTeam: winningTeam,
        gameCharacters: gameCharacters,
        characterService: characterService,
      );
    } finally {
      _endGameOperation = null;
    }
  }

  Future<void> _endGameOnce({
    required String? winningTeam,
    required List<Character> gameCharacters,
    required CharacterService? characterService,
  }) async {
    if (!gameIsRunning() &&
        _activeGameRecordCapture == null &&
        _chronicleService?.activeChronicle == null) {
      return;
    }
    final endedAt = _activeGameRecordCapture?.endedAt ?? _now();
    await _gameRecordUploadQueue.ready;
    await characterService?.flushPendingGameWrites();

    final sourceCharacters = characterService == null
        ? gameCharacters
        : characterService.gameCharactersWithoutDrunkAndFabled;
    final characterSnapshot = List<Character>.unmodifiable(
      sourceCharacters.map((character) => character.copyWith()),
    );
    final captureSnapshot = _finalGameRecordCapture(
      endedAt: endedAt,
      winningTeam: winningTeam,
      gameCharacters: characterSnapshot,
    );
    if (captureSnapshot != null) {
      _activeGameRecordCapture = captureSnapshot;
      await _saveActiveGameRecordCapture();
    }
    var chronicleSnapshot = await _chronicleService?.archiveCurrent(
      winningTeam: winningTeam,
      endedAt: endedAt,
    );
    if (chronicleSnapshot == null &&
        captureSnapshot != null &&
        _chronicleService?.lastChronicle?.gameId == captureSnapshot.gameId) {
      chronicleSnapshot = _chronicleService?.lastChronicle;
    }
    final record = _completeGameRecordFromChronicle(
      captureSnapshot,
      chronicleSnapshot,
    );
    if (record != null) {
      final queued = await _gameRecordUploadQueue.enqueue(record);
      final wasAlreadyQueued = _gameRecordUploadQueue.records
          .any((queuedRecord) => queuedRecord.gameId == record.gameId);
      if (!queued && !wasAlreadyQueued) {
        throw StateError('Completed GameRecord could not be persisted.');
      }
      if (queued || wasAlreadyQueued) {
        _lastCompletedGameRecord = record;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageLastGameRecordKey,
          jsonEncode(record.toJson()),
        );
      }
    }

    // Only after every snapshot has been validated and, if complete, durably
    // queued may mutable game and character state be reset.
    final resetFuture = Future.wait([
      resetCharacterTokens([]),
      resetCharacterAliveState(),
      _resetQuickFlowRuntime(),
      _clearGameTimer(),
      _clearDayTimer(),
    ]);
    _nightCount = -1;
    _nightStateNumber = 0;
    _currentNightStepId = null;
    _legacyNightStateNumber = null;
    await resetFuture;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_storageNightCountKey),
      prefs.remove(_storageNightStateNumberKey),
      prefs.remove(_storageNightStepIdKey),
      prefs.remove(_storageGameStartedAtKey),
      prefs.remove(_storageDayStartedAtKey),
      prefs.remove(_storageGameRecordCaptureKey),
      prefs.remove(_storageLastGameRecordCaptureKey),
    ]);
    _activeGameRecordCapture = null;
    _lastGameRecordCapture = null;
    await characterService?.endGame();
    notifyListeners();
  }

  Future<void> startNewGame(
    List<Character> gameCharacters, {
    List<Character>? completeSetupCharacters,
    List<Character>? scriptCatalog,
  }) async {
    await _nightOrderService.ready;
    await _scriptService.ready;
    await _chronicleService?.ready;
    final startedAt = _now();
    final gameId = _createGameRecordId(startedAt);
    final setupCharacters = completeSetupCharacters ?? gameCharacters;
    await _chronicleService?.startNewGame(
      gameCharacters,
      gameId: gameId,
      startedAt: startedAt,
    );
    await _clearDayTimer();
    await _startGameTimer(startedAt: startedAt);
    _nightCount = 1;
    final steps = _stepsFor(gameCharacters);
    await _beginGameRecordCapture(
      gameId: gameId,
      startedAt: startedAt,
      visiblePlayers: gameCharacters,
      setupCharacters: setupCharacters,
      scriptCatalog: scriptCatalog ?? setupCharacters,
      initialPhase:
          steps.isEmpty ? GameRecordPhaseType.day : GameRecordPhaseType.night,
    );
    if (steps.isEmpty) {
      await _startDayTimer(startedAt: startedAt);
    }
    await _setNightStep(
      steps.isEmpty ? 'day' : steps.first.id,
      gameCharacters: gameCharacters,
    );
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

  Duration get gameElapsed {
    final startedAt = _gameStartedAt;
    if (!gameIsRunning() || startedAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  bool isDawn() => _currentNightStepId == 'phase:dawn';

  bool isDay() => _currentNightStepId == 'day';

  Duration get dayElapsed {
    final startedAt = _dayStartedAt;
    if (startedAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  bool isDust() => _currentNightStepId == 'phase:dusk';

  Future<void> previousNightState(List<Character> characters) async {
    await _nightOrderService.ready;
    _ensureCurrentNightStep(characters);
    if (_currentNightStepId == 'day') {
      final steps = _stepsFor(characters);
      if (steps.isNotEmpty) {
        await _setNightStep(steps.last.id, gameCharacters: characters);
      }
      return;
    }
    var steps = _stepsFor(characters);
    final currentIndex =
        steps.indexWhere((step) => step.id == _currentNightStepId);
    if (currentIndex > 0) {
      await _setNightStep(
        steps[currentIndex - 1].id,
        gameCharacters: characters,
      );
      return;
    }
    if (_nightCount <= 1) return;
    _nightCount--;
    steps = _stepsFor(characters);
    await _setNightStep(
      steps.isEmpty ? 'day' : steps.last.id,
      gameCharacters: characters,
    );
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
      await _recordCurrentNightReminderSnapshot(gameCharacters);
      await _setNightStep(
        steps[currentIndex + 1].id,
        gameCharacters: gameCharacters,
      );
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
        await _recordCurrentNightReminderSnapshot(gameCharacters);
        await _setNightStep(next.id, gameCharacters: gameCharacters);
        return;
      }
    }
    await startDay(gameCharacters);
  }

  Future<void> startDay([List<Character> gameCharacters = const []]) async {
    await _recordCurrentNightReminderSnapshot(gameCharacters);
    final transitionAt = _now();
    final changed = await _transitionGameRecordPhase(
      GameRecordPhaseType.day,
      _nightCount,
      transitionAt,
    );
    if (changed || _dayStartedAt == null) {
      final capturedStart = _activeGameRecordCapture?.phases
          .lastWhereOrNull(
              (phase) => phase.isOpen && phase.type == GameRecordPhaseType.day)
          ?.startedAt;
      await _startDayTimer(
        startedAt: changed ? transitionAt : capturedStart ?? transitionAt,
      );
    }
    await _setNightStep('day', gameCharacters: gameCharacters);
  }

  Future<void> nextNight([List<Character> gameCharacters = const []]) async {
    await _nightOrderService.ready;
    final transitionAt = _now();
    await _clearDayTimer();
    _nightCount++;
    final steps = _stepsFor(gameCharacters);
    await _transitionGameRecordPhase(
      steps.isEmpty ? GameRecordPhaseType.day : GameRecordPhaseType.night,
      _nightCount,
      transitionAt,
    );
    if (steps.isEmpty) {
      await _startDayTimer(startedAt: transitionAt);
    }
    await _setNightStep(
      steps.isEmpty ? 'day' : steps.first.id,
      gameCharacters: gameCharacters,
    );
  }

  Future<void> previousNight(
      [List<Character> gameCharacters = const []]) async {
    await _nightOrderService.ready;
    if (_nightCount == 1) {
      return;
    }
    await _clearDayTimer();
    _nightCount--;
    final steps = _stepsFor(gameCharacters);
    await _setNightStep(
      steps.isEmpty ? 'day' : steps.last.id,
      gameCharacters: gameCharacters,
    );
  }

  List<NightStep> _stepsFor(List<Character> gameCharacters) {
    final travellerCount = gameCharacters
        .where((character) => character.fraction.name == 'traveller')
        .length;
    final regularPlayerCount = max(0, playerNames.length - travellerCount);
    return _nightOrderService
        .stepsFor(
          nightCount: _nightCount,
          gameCharacters: gameCharacters,
          regularPlayerCount: regularPlayerCount,
          isAlive: isCharacterAlive,
        )
        .where((step) => _shouldIncludeNightStep(step, gameCharacters))
        .toList(growable: false);
  }

  bool _shouldIncludeNightStep(
    NightStep step,
    List<Character> gameCharacters,
  ) {
    final character = gameCharacters.firstWhereOrNull(
      (candidate) => candidate.id == step.characterInstanceId,
    );
    if (character == null) return true;
    final wake = character.nightWake;
    final apparentDeathAllowsWake = wake.allowWhenApparentDead &&
        _apparentlyDeadCharacterIds.contains(character.id);
    if (!isCharacterAlive(character) && !apparentDeathAllowsWake) return false;
    if (_nightCount > 1 &&
        wake.otherNightsRequireNoDeathsPreviousDay &&
        _lastReportedDeathDay == _nightCount - 1) {
      return false;
    }
    return true;
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

  Future<void> _setNightStep(
    String stepId, {
    List<Character> gameCharacters = const [],
  }) async {
    _currentNightStepId = stepId;
    _legacyNightStateNumber = null;
    _nightStateNumber = stepId == 'day' ? 0 : 1;
    await _persistNightPosition();
    final phase = currentChroniclePhase;
    await _chronicleService?.recordPhase(phase, _nightCount);
    if (stepId.startsWith('role:')) {
      final character = gameCharacters.firstWhereOrNull(
        (candidate) => stepId == 'role:${candidate.roleId}:${candidate.id}',
      );
      if (character != null) {
        await _chronicleService?.recordNightVisit(character, _nightCount);
      }
    }
    notifyListeners();
  }

  Future<void> _recordCurrentNightReminderSnapshot(
    List<Character> gameCharacters,
  ) async {
    if (_nightCount < 1 ||
        _currentNightStepId == null ||
        !_currentNightStepId!.startsWith('role:')) {
      return;
    }
    for (final entry in quickFlowEntries(gameCharacters)) {
      if (entry.step.type != QuickFlowStepType.reminder ||
          entry.step.operation == QuickFlowReminderOperation.setOnce) {
        continue;
      }
      final token = quickFlowToken(entry);
      if (token == null) continue;
      final targets = quickFlowTargets(entry, gameCharacters);
      await _chronicleService?.recordQuickFlowReminderSnapshot(
        owner: entry.owner,
        stepId: entry.step.id,
        token: token,
        targets: targets,
        round: _nightCount,
      );
    }
  }

  ChroniclePhase get currentChroniclePhase {
    if (_nightCount < 1) return ChroniclePhase.setup;
    return _currentNightStepId == 'day'
        ? ChroniclePhase.day
        : ChroniclePhase.night;
  }

  static const _playgroundChronicleEntryId = 'playground-input';

  /// Returns the automatic Chronicle input declared for the active night
  /// step. JSON currently declares at most one automatic definition per
  /// character and phase; forms can still contain several input fields.
  ActiveNightChronicleInput? activeNightChronicleInput(
    List<Character> gameCharacters,
  ) {
    if (currentChroniclePhase != ChroniclePhase.night || _nightCount < 1) {
      return null;
    }
    final owner = getAwakeCharacter(gameCharacters);
    if (owner == null) return null;
    final definition =
        owner.chronicle?.definitionsForNight(_nightCount).firstOrNull;
    if (definition == null) return null;
    final fields = ActiveNightChronicleInput.flattenFields(definition);
    if (!fields.any((field) =>
        field.type == ChronicleInputType.player ||
        field.type == ChronicleInputType.players ||
        field.type == ChronicleInputType.yesNo ||
        field.type == ChronicleInputType.number)) {
      return null;
    }
    final event = _chronicleService?.activeChronicle?.events.firstWhereOrNull(
      (item) =>
          item.type == ChronicleEventType.nightInformation &&
          item.round == _nightCount &&
          item.character?.characterId == owner.id &&
          item.inputDefinition?.id == definition.id,
    );
    final entry = event?.informationEntries.firstWhereOrNull(
      (item) => item['entryId'] == _playgroundChronicleEntryId,
    );
    final values = entry?['values'] is Map
        ? Map<String, dynamic>.from(entry!['values'] as Map)
        : <String, dynamic>{};
    return ActiveNightChronicleInput(
      owner: owner,
      definition: definition,
      eventId: event?.id,
      values: values,
    );
  }

  /// Chronicle player input is an additional playground interaction. It must
  /// never replace an active QuickFlow reminder assignment: character taps
  /// need to keep reaching the established reminder-token handler first.
  /// Once that assignment has advanced, a separate Chronicle player field can
  /// use the normal token taps for its optional input.
  bool isNightChroniclePlayerSelectionActive(
    List<Character> gameCharacters,
  ) =>
      activeNightChronicleInput(gameCharacters)?.hasPlayerField == true &&
      activeQuickFlowReminder(gameCharacters) == null;

  Future<void> toggleNightChroniclePlayer(
    ActiveNightChronicleInput input,
    Character player,
  ) async {
    final field = input.playerFieldFor(player.id);
    if (field == null) return;
    final values = _storedNightChronicleValues(input);
    final selected = _chroniclePlayerSnapshots(field, values);
    final index = selected.indexWhere(
      (snapshot) => snapshot.characterId == player.id,
    );
    if (index >= 0) {
      selected.removeAt(index);
    } else {
      final maximum = field.effectiveMaxCount;
      if (maximum != null && selected.length >= maximum) {
        // Keep the first choice and replace the most recently selected one.
        selected.removeLast();
      }
      selected.add(ChronicleCharacterSnapshot.fromCharacter(player));
    }
    if (selected.isEmpty) {
      values.remove(field.id);
    } else if (field.type == ChronicleInputType.player) {
      values[field.id] = selected.single.toJson();
    } else {
      values[field.id] = selected.map((item) => item.toJson()).toList();
    }
    await _saveNightChronicleInput(input, values);
  }

  Future<void> toggleNightChronicleYesNo(
    ActiveNightChronicleInput input,
    ChronicleInputDefinition field,
    bool value,
  ) async {
    final values = _storedNightChronicleValues(input);
    if (values[field.id] == value) {
      values.remove(field.id);
    } else {
      values[field.id] = value;
    }
    await _saveNightChronicleInput(input, values);
  }

  Future<void> toggleNightChronicleNumber(
    ActiveNightChronicleInput input,
    ChronicleInputDefinition field,
    int value,
  ) async {
    final values = _storedNightChronicleValues(input);
    if (values[field.id] == value) {
      values.remove(field.id);
    } else {
      values[field.id] = value;
    }
    await _saveNightChronicleInput(input, values);
  }

  Future<void> _saveNightChronicleInput(
    ActiveNightChronicleInput input,
    Map<String, dynamic> values,
  ) async {
    var eventId = input.eventId;
    if (eventId == null && values.isNotEmpty) {
      final event = await _chronicleService?.addOptionalInformation(
        character: ChronicleCharacterSnapshot.fromCharacter(input.owner),
        definition: input.definition,
        round: _nightCount,
      );
      eventId = event?.id;
    }
    if (eventId == null) return;
    if (values.isEmpty) {
      await _chronicleService?.deleteInformationEntry(
        eventId: eventId,
        entryId: _playgroundChronicleEntryId,
      );
    } else {
      await _chronicleService?.saveInformationEntry(
        eventId: eventId,
        entryId: _playgroundChronicleEntryId,
        values: values,
        targets: _chroniclePlayerTargets(input.definition, values),
      );
    }
    notifyListeners();
  }

  Map<String, dynamic> _storedNightChronicleValues(
    ActiveNightChronicleInput input,
  ) {
    if (input.eventId == null) return <String, dynamic>{};
    final event = _chronicleService?.activeChronicle?.events
        .firstWhereOrNull((item) => item.id == input.eventId);
    final entry = event?.informationEntries.firstWhereOrNull(
      (item) => item['entryId'] == _playgroundChronicleEntryId,
    );
    return entry?['values'] is Map
        ? Map<String, dynamic>.from(entry!['values'] as Map)
        : <String, dynamic>{};
  }

  List<ChronicleCharacterSnapshot> _chroniclePlayerSnapshots(
    ChronicleInputDefinition field,
    Map<String, dynamic> values,
  ) {
    final raw = values[field.id];
    final items = field.type == ChronicleInputType.players
        ? (raw is List ? raw : const [])
        : [if (raw is Map) raw];
    return items
        .whereType<Map>()
        .map((item) => ChronicleCharacterSnapshot.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: true);
  }

  List<ChronicleCharacterSnapshot> _chroniclePlayerTargets(
    ChronicleInputDefinition definition,
    Map<String, dynamic> values,
  ) {
    final targets = <ChronicleCharacterSnapshot>[];
    for (final field in ActiveNightChronicleInput.flattenFields(definition)) {
      if (field.type != ChronicleInputType.player &&
          field.type != ChronicleInputType.players) {
        continue;
      }
      for (final snapshot in _chroniclePlayerSnapshots(field, values)) {
        if (!targets.any((item) => item.characterId == snapshot.characterId)) {
          targets.add(snapshot);
        }
      }
    }
    return targets;
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

  String _quickFlowCompletionKey(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) =>
      '${_quickFlowContextKey(quickFlowEntries(gameCharacters))}:${entry.key}';

  bool isQuickFlowEntryCompleted(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) =>
      _quickFlowCompletedSteps
          .contains(_quickFlowCompletionKey(entry, gameCharacters));

  QuickFlowEntry? activeQuickFlowEntry(List<Character> gameCharacters) {
    final entries = quickFlowEntries(gameCharacters);
    final contextKey = _quickFlowContextKey(entries);
    if (contextKey == null) return null;
    if (_activeQuickFlowContextKey == contextKey) {
      if (_activeQuickFlowStepKey == null) return null;
      final active = entries.firstWhereOrNull(
        (entry) =>
            entry.key == _activeQuickFlowStepKey &&
            isQuickFlowEntrySupported(entry) &&
            !isQuickFlowEntryCompleted(entry, gameCharacters),
      );
      if (active != null) return active;
    }

    return entries.firstWhereOrNull((entry) =>
        isQuickFlowEntrySupported(entry) &&
        !isQuickFlowEntryCompleted(entry, gameCharacters));
  }

  QuickFlowEntry? activeQuickFlowReminder(List<Character> gameCharacters) {
    final active = activeQuickFlowEntry(gameCharacters);
    return active?.step.type == QuickFlowStepType.reminder ? active : null;
  }

  bool isQuickFlowEntryActive(
          QuickFlowEntry entry, List<Character> gameCharacters) =>
      activeQuickFlowEntry(gameCharacters)?.key == entry.key;

  Future<void> activateQuickFlowEntry(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) async {
    if (!isQuickFlowEntrySupported(entry)) {
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

  /// Captures the role that an automatic character-token step resolved to at
  /// the time its source player was chosen. This deliberately happens before
  /// any later, storyteller-controlled role swap can change that player's
  /// current role.
  void _prefillQuickFlowCharacterSelections(
    QuickFlowEntry source,
    Character target,
  ) {
    for (final step in source.owner.quickFlow.stepsFor(source.phase)) {
      if (step.type != QuickFlowStepType.reminderCharacterToken ||
          step.selection?.type != 'fromReminderTarget' ||
          step.selection?.stepId != source.step.id) {
        continue;
      }
      final entry = QuickFlowEntry(
        owner: source.owner,
        phase: source.phase,
        step: step,
      );
      if (!_quickFlowManualOverrides.contains(entry.key)) {
        _quickFlowCharacterSelections[entry.key] = target.roleId;
      }
    }
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
      _prefillQuickFlowCharacterSelections(entry, target);
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
      _prefillQuickFlowCharacterSelections(entry, target);
      await _advanceQuickFlowAfter(entry, gameCharacters);
      return QuickFlowAssignmentResult.success(warning: warning);
    }
    await addTokenToCharacter(
      gameCharacters,
      target,
      token,
      source: 'quickFlow',
      quickFlowStepId: entry.step.id,
      quickFlowOwner: entry.owner,
    );
    _recordQuickFlowStepTarget(entry, target);
    _prefillQuickFlowCharacterSelections(entry, target);
    await _advanceQuickFlowAfter(entry, gameCharacters);
    return QuickFlowAssignmentResult.success(warning: warning);
  }

  Future<void> _advanceQuickFlowAfter(
    QuickFlowEntry current,
    List<Character> gameCharacters,
  ) async {
    final entries = quickFlowEntries(gameCharacters);
    if (current.step.type != QuickFlowStepType.reminder) {
      _quickFlowCompletedSteps
          .add(_quickFlowCompletionKey(current, gameCharacters));
    }
    _activeQuickFlowContextKey = _quickFlowContextKey(entries);
    final currentIndex =
        entries.indexWhere((entry) => entry.key == current.key);
    _activeQuickFlowStepKey = currentIndex < 0
        ? null
        : entries
            .skip(currentIndex + 1)
            .firstWhereOrNull((entry) =>
                isQuickFlowEntrySupported(entry) &&
                !isQuickFlowEntryCompleted(entry, gameCharacters))
            ?.key;
    await _saveQuickFlowState();
    notifyListeners();
  }

  Future<void> completeQuickFlowEntry(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) =>
      _advanceQuickFlowAfter(entry, gameCharacters);

  Character? quickFlowSelectedCharacter(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    if (entry.step.type != QuickFlowStepType.reminderCharacterToken) {
      return null;
    }
    final storedRoleId = _quickFlowCharacterSelections[entry.key];
    if (storedRoleId != null) {
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
        !_isQuickFlowCharacterAllowed(entry, character)) {
      return false;
    }
    if (_quickFlowCharacterSelections[entry.key] == character.roleId &&
        _quickFlowManualOverrides.contains(entry.key)) {
      return true;
    }
    _quickFlowCharacterSelections[entry.key] = character.roleId;
    _quickFlowManualOverrides.add(entry.key);
    await _saveQuickFlowState();
    await _chronicleService?.recordQuickFlowCharacterSelection(
      owner: entry.owner,
      selected: character,
      stepId: entry.step.id,
      phase: currentChroniclePhase,
      round: _nightCount,
    );
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

  Character? quickFlowInfoRecipient(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
  ) {
    return switch (entry.step.recipient?.type) {
      'abilityOwner' => entry.owner,
      'reminderTarget' when entry.step.recipient?.stepId != null =>
        quickFlowTarget(
          _entryForStepId(
                entry.owner,
                entry.phase,
                entry.step.recipient!.stepId!,
              ) ??
              entry,
          gameCharacters,
        ),
      _ => null,
    };
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
    return quickFlowInfoRecipient(entry, gameCharacters) != null &&
        entry.step.requires.every((stepId) => _isQuickFlowRequiredStepComplete(
            entry, stepId, gameCharacters, allCharacters));
  }

  String _quickFlowConfirmationKey(QuickFlowEntry entry) =>
      '${entry.key}:night:$_nightCount';

  bool quickFlowInfoNeedsConfirmation(QuickFlowEntry entry) =>
      entry.step.showOnlyWhen?.type == 'storytellerConfirmed' &&
      !isQuickFlowInfoSkipped(entry) &&
      !_quickFlowConfirmedInfo.contains(_quickFlowConfirmationKey(entry));

  bool isQuickFlowInfoSkipped(QuickFlowEntry entry) =>
      _quickFlowSkippedInfo.contains(_quickFlowConfirmationKey(entry));

  Future<void> confirmQuickFlowInfo(QuickFlowEntry entry) async {
    final confirmationKey = _quickFlowConfirmationKey(entry);
    _quickFlowSkippedInfo.remove(confirmationKey);
    if (!_quickFlowConfirmedInfo.add(confirmationKey)) return;
    await _saveQuickFlowState();
    await _chronicleService?.recordQuickFlowInfo(
      owner: entry.owner,
      stepId: entry.step.id,
      phase: currentChroniclePhase,
      round: _nightCount,
    );
    notifyListeners();
  }

  Future<void> skipQuickFlowInfo(QuickFlowEntry entry) async {
    final confirmationKey = _quickFlowConfirmationKey(entry);
    if (!_quickFlowSkippedInfo.add(confirmationKey)) return;
    _quickFlowConfirmedInfo.remove(confirmationKey);
    await _saveQuickFlowState();
    notifyListeners();
  }

  QuickFlowInfo? buildQuickFlowInfo(
    QuickFlowEntry entry,
    List<Character> gameCharacters,
    List<Character> allCharacters,
  ) {
    if (!isQuickFlowInfoReady(entry, gameCharacters, allCharacters) ||
        quickFlowInfoNeedsConfirmation(entry) ||
        isQuickFlowInfoSkipped(entry)) {
      return null;
    }
    final presentation = entry.step.presentation!;
    final recipient = quickFlowInfoRecipient(entry, gameCharacters);
    if (recipient == null) return null;
    final playerStepIds = <String>[
      ...presentation.playerSteps,
      if (presentation.playerStep != null) presentation.playerStep!,
    ];
    final players = <Character>[];
    for (final stepId in playerStepIds) {
      final playerEntry = _entryForStepId(entry.owner, entry.phase, stepId);
      final targets = playerEntry == null
          ? const <Character>[]
          : quickFlowTargets(playerEntry, gameCharacters);
      for (final target in targets) {
        if (!players.any((item) => item.id == target.id)) {
          players.add(target);
        }
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
    final selectedCharacters = <Character>[];
    final characterStepIds = <String>[
      ...presentation.characterSteps,
      if (presentation.characterStep != null) presentation.characterStep!,
    ];
    for (final characterStepId in characterStepIds) {
      final characterEntry = _entryForStepId(
        entry.owner,
        entry.phase,
        characterStepId,
      );
      if (characterEntry != null) {
        final selectedCharacter = quickFlowSelectedCharacter(
          characterEntry,
          gameCharacters,
          allCharacters,
        );
        if (selectedCharacter != null &&
            !selectedCharacters
                .any((item) => item.roleId == selectedCharacter.roleId)) {
          selectedCharacters.add(selectedCharacter);
        }
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
      recipient: recipient,
      sourceCharacter: sourceCharacter,
      selectedCharacter: selectedCharacters.firstOrNull,
      selectedCharacters: selectedCharacters,
      players: players,
      infoToken: presentation.infoToken,
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
    _apparentlyDeadCharacterIds.clear();
    _lastReportedDeathDay = null;
    await Future.wait([_saveCharacterAliveState(), _saveApparentDeathState()]);
    notifyListeners();
  }

  Future<void> toggleCharacterAlive(Character character) async {
    final wasAlive = isCharacterAlive(character);
    final wasApparentlyDead =
        _apparentlyDeadCharacterIds.contains(character.id);
    bool? recordedLifeStatus;
    if (wasAlive) {
      _characterAliveState[character.id] = false;
      if (character.nightWake.allowWhenApparentDead) {
        _apparentlyDeadCharacterIds.add(character.id);
      } else {
        recordedLifeStatus = false;
      }
      if (isDay()) _lastReportedDeathDay = _nightCount;
    } else if (wasApparentlyDead) {
      // A second death marking finalizes an apparent death without reviving.
      _apparentlyDeadCharacterIds.remove(character.id);
      _characterAliveState[character.id] = false;
      recordedLifeStatus = false;
      if (isDay()) _lastReportedDeathDay = _nightCount;
    } else {
      _characterAliveState[character.id] = true;
      recordedLifeStatus = true;
    }
    await Future.wait([_saveCharacterAliveState(), _saveApparentDeathState()]);
    if (recordedLifeStatus != null) {
      await _chronicleService?.recordLifeStatus(
        character: character,
        alive: recordedLifeStatus,
        phase: currentChroniclePhase,
        round: _nightCount,
      );
    }
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

  Future<void> reorderPlayerNames(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String playerName = playerNames.removeAt(oldIndex);
    playerNames.insert(newIndex, playerName);
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(playerNames);
    await prefs.setString(_storagePlayerNamesKey, data);
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
    List<Character> allCharacters,
    Character character,
    Token token, {
    String source = 'manual',
    String? quickFlowStepId,
    Character? quickFlowOwner,
  }) async {
    if (tokensOfCharacter(character).contains(token)) return;
    final previousTarget = token.unlimited
        ? null
        : allCharacters.firstWhereOrNull(
            (candidate) => tokensOfCharacter(candidate).contains(token),
          );
    if (previousTarget?.id == character.id) return;
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
    await _applyActualStartRoleMarker(
      allCharacters: allCharacters,
      target: character,
      token: token,
    );
    await _chronicleService?.recordReminderAssignment(
      target: character,
      previousTarget: previousTarget,
      token: token,
      phase: currentChroniclePhase,
      round: _nightCount,
      source: source,
      quickFlowStepId: quickFlowStepId,
      quickFlowOwner: quickFlowOwner,
    );
    notifyListeners();
  }

  Future<void> removeTokenFromCharacter(
      Character character, Token token) async {
    if (_characterTokens.containsKey(character.id)) {
      final removed = _characterTokens[character.id]!.remove(token);
      if (!removed) return;
      unsedGameTokens.add(token);
      await _saveCharacterTokens();
      await _chronicleService?.recordReminderRemoval(
        target: character,
        token: token,
        phase: currentChroniclePhase,
        round: _nightCount,
      );
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
  DateTime? get gameStartedAt => _gameStartedAt;
  GameRecordCapture? get activeGameRecordCapture => _activeGameRecordCapture;
  GameRecordCapture? get lastGameRecordCapture => _lastGameRecordCapture;
  GameRecord? get lastCompletedGameRecord => _lastCompletedGameRecord;
  List<GameRecord> get pendingGameRecords => _gameRecordUploadQueue.records;
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
