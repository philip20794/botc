import 'dart:convert';

import 'package:blood_on_the_clocktower/models/botc_script.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/gameset.dart';
import 'package:blood_on_the_clocktower/models/game_record.dart';
import 'package:blood_on_the_clocktower/models/script_import.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScriptService extends ChangeNotifier {
  static const troubleBrewingId = 'standard:trouble_brewing';
  static const sectsAndVioletsId = 'standard:sects_and_violets';
  static const badMoonRisingId = 'standard:bad_moon_rising';
  static const experimentalId = 'standard:experimental';

  static const _scriptsStorageKey = 'custom_scripts';
  static const _complexityOverridesStorageKey = 'script_complexity_overrides';
  static const _selectedScriptStorageKey = 'selected_script_id';
  static const _legacyGamesetStorageKey = 'gameset';

  static final List<BotcScript> standardScripts = [
    BotcScript(
      id: troubleBrewingId,
      name: 'Trouble Brewing',
      roleIds: const [
        'washerwoman',
        'librarian',
        'investigator',
        'chef',
        'empath',
        'fortuneteller',
        'mayor',
        'monk',
        'ravenkeeper',
        'slayer',
        'soldier',
        'undertaker',
        'virgin',
        'butler',
        'drunk',
        'recluse',
        'saint',
        'baron',
        'poisoner',
        'scarletwoman',
        'spy',
        'imp',
        'scapegoat',
        'gunslinger',
        'beggar',
        'bureaucrat',
        'thief',
      ],
    ),
    BotcScript(
      id: sectsAndVioletsId,
      name: 'Sects & Violets',
      roleIds: const [
        'clockmaker',
        'dreamer',
        'snakecharmer',
        'mathematician',
        'flowergirl',
        'towncrier',
        'oracle',
        'savant',
        'seamstress',
        'philosopher',
        'artist',
        'juggler',
        'sage',
        'mutant',
        'sweetheart',
        'barber',
        'klutz',
        'eviltwin',
        'witch',
        'cerenovus',
        'pithag',
        'fanggu',
        'vigormortis',
        'nodashii',
        'vortox',
        'butcher',
        'bonecollector',
        'harlot',
        'barista',
        'deviant',
      ],
    ),
    BotcScript(
      id: badMoonRisingId,
      name: 'Bad Moon Rising',
      roleIds: const [
        'grandmother',
        'sailor',
        'chambermaid',
        'exorcist',
        'innkeeper',
        'gambler',
        'gossip',
        'courtier',
        'professor',
        'minstrel',
        'tealady',
        'pacifist',
        'fool',
        'goon',
        'lunatic',
        'tinker',
        'moonchild',
        'godfather',
        'devilsadvocate',
        'assassin',
        'mastermind',
        'zombuul',
        'pukka',
        'shabaloth',
        'po',
        'apprentice',
        'matron',
        'voudon',
        'judge',
        'bishop',
      ],
    ),
    BotcScript(id: experimentalId, name: 'Experimental', roleIds: const []),
  ];

  static const _standardComplexities = <String, _ScriptComplexities>{
    troubleBrewingId: _ScriptComplexities(storyteller: 1.5, player: 1.5),
    sectsAndVioletsId: _ScriptComplexities(storyteller: 3.5, player: 3.5),
    badMoonRisingId: _ScriptComplexities(storyteller: 4, player: 3.5),
  };

  final List<BotcScript> _customScripts = [];
  final Map<String, _ScriptComplexities> _standardComplexityOverrides = {};
  String _selectedScriptId = troubleBrewingId;
  late final Future<void> ready;

  ScriptService() {
    ready = _load();
  }

  List<BotcScript> get customScripts => List.unmodifiable(_customScripts);
  List<BotcScript> get scripts =>
      List.unmodifiable([...standardScripts, ..._customScripts]);
  String get selectedScriptId => _selectedScriptId;
  BotcScript get selectedScript =>
      scripts.firstWhere((script) => script.id == _selectedScriptId);

  /// Immutable script data used by a game record. Experimental scripts are
  /// resolved from the supplied catalog because their stored role list is
  /// intentionally empty.
  GameRecordScript gameRecordSnapshot(List<Character> catalog) {
    final script = selectedScript;
    final roleIds = _selectedScriptId == experimentalId
        ? resolveCharacters(catalog)
            .map((character) => character.roleId)
            .toSet()
            .toList(growable: false)
        : List<String>.from(script.roleIds);
    return GameRecordScript(
      scriptId: script.id,
      name: script.name,
      isCustom: _customScripts.any((custom) => custom.id == script.id),
      roleIds: roleIds,
      contentHash: GameRecordScript.contentHashForRoleIds(roleIds),
    );
  }

  double? storytellerComplexityFor(String scriptId) {
    final custom = _customScripts.cast<BotcScript?>().firstWhere(
          (script) => script?.id == scriptId,
          orElse: () => null,
        );
    if (custom != null) return custom.storytellerComplexity;
    return _standardComplexityOverrides.containsKey(scriptId)
        ? _standardComplexityOverrides[scriptId]!.storyteller
        : _standardComplexities[scriptId]?.storyteller;
  }

  double? playerComplexityFor(String scriptId) {
    final custom = _customScripts.cast<BotcScript?>().firstWhere(
          (script) => script?.id == scriptId,
          orElse: () => null,
        );
    if (custom != null) return custom.playerComplexity;
    return _standardComplexityOverrides.containsKey(scriptId)
        ? _standardComplexityOverrides[scriptId]!.player
        : _standardComplexities[scriptId]?.player;
  }

  bool hasComplexityOverride(String scriptId) =>
      _standardComplexityOverrides.containsKey(scriptId);

  Future<void> setComplexities(
    String scriptId, {
    required double? storytellerComplexity,
    required double? playerComplexity,
  }) async {
    await ready;
    BotcScript.validateComplexity(
      storytellerComplexity,
      'storytellerComplexity',
    );
    BotcScript.validateComplexity(playerComplexity, 'playerComplexity');
    final customIndex = _customScripts.indexWhere(
      (script) => script.id == scriptId,
    );
    if (customIndex != -1) {
      _customScripts[customIndex] =
          _customScripts[customIndex].withComplexities(
        storytellerComplexity: storytellerComplexity,
        playerComplexity: playerComplexity,
      );
      await _saveScripts();
    } else if (standardScripts.any((script) => script.id == scriptId)) {
      _standardComplexityOverrides[scriptId] = _ScriptComplexities(
        storyteller: storytellerComplexity,
        player: playerComplexity,
      );
      await _saveComplexityOverrides();
    } else {
      throw ArgumentError.value(scriptId, 'scriptId', 'Unknown BOTC script');
    }
    notifyListeners();
  }

  Future<void> resetComplexities(String scriptId) async {
    await ready;
    if (!_standardComplexityOverrides.containsKey(scriptId)) return;
    _standardComplexityOverrides.remove(scriptId);
    await _saveComplexityOverrides();
    notifyListeners();
  }

  Gameset? get selectedGameset => switch (_selectedScriptId) {
        troubleBrewingId => Gameset.trouble_brewing,
        sectsAndVioletsId => Gameset.sects_and_violets,
        badMoonRisingId => Gameset.bad_moon_rising,
        experimentalId => Gameset.experimental,
        _ => null,
      };

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedScripts = prefs.getStringList(_scriptsStorageKey) ?? const [];
    for (final encoded in encodedScripts) {
      try {
        _customScripts.add(BotcScript.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        ));
      } on FormatException {
        // Keep valid saved scripts when one historic entry is malformed.
      } on TypeError {
        // Keep valid saved scripts when one historic entry is malformed.
      }
    }
    _loadComplexityOverrides(prefs.getString(_complexityOverridesStorageKey));

    final storedSelection = prefs.getString(_selectedScriptStorageKey);
    if (storedSelection != null &&
        scripts.any((script) => script.id == storedSelection)) {
      _selectedScriptId = storedSelection;
    } else {
      _selectedScriptId = _scriptIdForLegacyGameset(
        prefs.getString(_legacyGamesetStorageKey),
      );
    }
    notifyListeners();
  }

  Future<void> upsertScript(BotcScript script) async {
    await ready;
    _validateCustomScript(script);
    final index = _customScripts.indexWhere((item) => item.id == script.id);
    if (index == -1) {
      _customScripts.add(script);
    } else {
      _customScripts[index] = script;
    }
    await _saveScripts();
    notifyListeners();
  }

  Future<bool> removeScript(
    String id, {
    required bool gameIsRunning,
  }) async {
    await ready;
    if (gameIsRunning) return false;
    final index = _customScripts.indexWhere((script) => script.id == id);
    if (index == -1) return false;
    _customScripts.removeAt(index);
    if (_selectedScriptId == id) {
      _selectedScriptId = troubleBrewingId;
      await _saveSelection();
    }
    await _saveScripts();
    notifyListeners();
    return true;
  }

  Future<bool> selectScript(
    String id, {
    required bool gameIsRunning,
  }) async {
    await ready;
    if (gameIsRunning) return false;
    if (!scripts.any((script) => script.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown BOTC script');
    }
    if (_selectedScriptId == id) return true;
    _selectedScriptId = id;
    await _saveSelection();
    notifyListeners();
    return true;
  }

  List<Character> resolveCharacters(List<Character> catalog) {
    if (_selectedScriptId == experimentalId) {
      return catalog
          .where(
              (character) => character.gameset.contains(Gameset.experimental))
          .toList();
    }
    final byRoleId = {
      for (final character in catalog) character.roleId: character,
    };
    return selectedScript.roleIds
        .map((roleId) => byRoleId[roleId])
        .whereType<Character>()
        .toList();
  }

  List<String> unresolvedRoleIds(List<Character> catalog) {
    if (_selectedScriptId == experimentalId) return const [];
    final available = catalog.map((character) => character.roleId).toSet();
    return selectedScript.roleIds
        .where((roleId) => !available.contains(roleId))
        .toList();
  }

  /// Parses a script against the complete English reference catalog, without
  /// modifying custom scripts or the active selection.
  Future<ScriptImportResult> inspectImportJson(
    String source,
    CharacterService characterService,
  ) async {
    final canonicalCatalog =
        await characterService.loadCanonicalCharacterCatalog();
    return inspectImportJsonAgainstCatalog(source, canonicalCatalog);
  }

  ScriptImportResult inspectImportJsonAgainstCatalog(
    String source,
    Iterable<Character> canonicalCatalog,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return ScriptImportResult(validationIssues: [
        ScriptImportIssue(
          type: ScriptImportIssueType.invalidJson,
          message: 'The script is not valid JSON.',
        ),
      ]);
    }

    final structure = _readImportStructure(decoded);
    if (structure == null) {
      return ScriptImportResult(validationIssues: [
        ScriptImportIssue(
          type: ScriptImportIssueType.invalidStructure,
          message:
              'Expected a script array or object with role entries.',
        ),
      ]);
    }

    final issues = <ScriptImportIssue>[];
    final meta = structure.meta;
    String? name;
    String? author;
    if (meta != null) {
      final rawName = meta['name'];
      if (rawName is String) {
        if (rawName.trim().isNotEmpty) name = rawName.trim();
      } else if (rawName != null) {
        issues.add(ScriptImportIssue(
          type: ScriptImportIssueType.invalidMetadata,
          message: 'The _meta name must be a string when provided.',
        ));
      }
      final rawAuthor = meta['author'];
      if (rawAuthor != null && rawAuthor is! String) {
        issues.add(ScriptImportIssue(
          type: ScriptImportIssueType.invalidMetadata,
          message: 'The _meta author must be a string when provided.',
        ));
      } else if (rawAuthor is String && rawAuthor.trim().isNotEmpty) {
        author = rawAuthor.trim();
      }
    }
    if (structure.hasInvalidMeta) {
      issues.add(ScriptImportIssue(
        type: ScriptImportIssueType.invalidMetadata,
        message: 'The _meta entry must be an object.',
      ));
    }
    if (structure.hasDuplicateMeta) {
      issues.add(ScriptImportIssue(
        type: ScriptImportIssueType.invalidMetadata,
        message: 'The script contains more than one _meta entry.',
      ));
    }
    if (structure.roles.isEmpty) {
      issues.add(ScriptImportIssue(
        type: ScriptImportIssueType.invalidStructure,
        message: 'The script does not contain any roles.',
      ));
    }

    final canonicalByRoleId = <String, List<Character>>{};
    for (final character in canonicalCatalog) {
      (canonicalByRoleId[character.roleId] ??= []).add(character);
    }

    final roles = <ImportedScriptRole>[];
    for (var index = 0; index < structure.roles.length; index++) {
      roles.add(_inspectImportedRole(
        index,
        structure.roles[index],
        canonicalByRoleId,
      ));
    }
    return ScriptImportResult(
      name: name,
      author: author,
      roles: roles,
      validationIssues: issues,
    );
  }

  /// Maps one unresolved imported role to an existing canonical role. The
  /// result remains a draft; persistence still requires confirmation.
  Future<ScriptImportResult> mapImportedRole(
    ScriptImportResult draft, {
    required int roleIndex,
    required String canonicalRoleId,
    required CharacterService characterService,
  }) async {
    final canonicalCatalog =
        await characterService.loadCanonicalCharacterCatalog();
    return mapImportedRoleAgainstCatalog(
      draft,
      roleIndex: roleIndex,
      canonicalRoleId: canonicalRoleId,
      canonicalCatalog: canonicalCatalog,
    );
  }

  ScriptImportResult mapImportedRoleAgainstCatalog(
    ScriptImportResult draft, {
    required int roleIndex,
    required String canonicalRoleId,
    required Iterable<Character> canonicalCatalog,
  }) {
    ImportedScriptRole? role;
    for (final candidate in draft.roles) {
      if (candidate.index == roleIndex) {
        role = candidate;
        break;
      }
    }
    if (role == null || role.sourceId == null) {
      throw ArgumentError.value(roleIndex, 'roleIndex', 'Unknown import role');
    }
    if (role.isResolved) {
      throw StateError('Only unresolved import roles may be mapped.');
    }
    final candidates = canonicalCatalog
        .where((character) => character.roleId == canonicalRoleId)
        .toList(growable: false);
    if (candidates.length != 1) {
      throw ArgumentError.value(
        canonicalRoleId,
        'canonicalRoleId',
        'Expected exactly one canonical role.',
      );
    }
    return draft.withResolvedRole(roleIndex, candidates.single.roleId);
  }

  /// Persists a fully resolved draft only after the caller has explicitly
  /// confirmed the import.
  Future<BotcScript> confirmImport(
    ScriptImportResult draft, {
    String? scriptId,
    double? storytellerComplexity,
    double? playerComplexity,
  }) async {
    await ready;
    if (!draft.canBeConfirmed) {
      throw StateError('Resolve all import issues before saving the script.');
    }
    final id = scriptId?.trim();
    if (id != null && id.isEmpty) {
      throw ArgumentError.value(scriptId, 'scriptId', 'Must not be empty');
    }
    final script = BotcScript(
      id: id ?? _newImportedScriptId(),
      name: draft.name!,
      author: draft.author,
      roleIds: draft.resolvedRoleIds,
      storytellerComplexity: storytellerComplexity,
      playerComplexity: playerComplexity,
    );
    await upsertScript(script);
    return script;
  }

  _ImportStructure? _readImportStructure(dynamic decoded) {
    if (decoded is List<dynamic>) {
      final metaEntries = decoded
          .whereType<Map>()
          .where((entry) => entry['id'] == '_meta')
          .cast<Map<String, dynamic>>()
          .toList();
      return _ImportStructure(
        meta: metaEntries.length == 1 ? metaEntries.single : null,
        hasDuplicateMeta: metaEntries.length > 1,
        roles: decoded
            .where((entry) => entry is! Map || entry['id'] != '_meta')
            .toList(),
      );
    }
    if (decoded is Map<String, dynamic>) {
      final rawRoles = decoded['roles'] ?? decoded['characters'];
      if (rawRoles is! List<dynamic>) {
        return null;
      }
      final rawMeta = decoded['_meta'];
      return _ImportStructure(
        meta: rawMeta is Map<String, dynamic> ? rawMeta : null,
        hasInvalidMeta: rawMeta != null && rawMeta is! Map<String, dynamic>,
        roles: rawRoles,
      );
    }
    return null;
  }

  ImportedScriptRole _inspectImportedRole(
    int index,
    dynamic entry,
    Map<String, List<Character>> canonicalByRoleId,
  ) {
    String? sourceId;
    var isHomebrewDefinition = false;
    if (entry is String) {
      sourceId = entry.trim();
    } else if (entry is Map) {
      final rawId = entry['id'];
      if (rawId is String) {
        sourceId = rawId.trim();
      }
      isHomebrewDefinition = _containsHomebrewDefinition(entry);
    }
    if (sourceId == null || sourceId.isEmpty) {
      return ImportedScriptRole(
        index: index,
        issue: ScriptImportIssue(
          type: ScriptImportIssueType.invalidRoleEntry,
          message:
              'Each role must be a non-empty ID string or an object with an ID.',
          roleIndex: index,
        ),
      );
    }
    if (isHomebrewDefinition) {
      return ImportedScriptRole(
        index: index,
        sourceId: sourceId,
        issue: ScriptImportIssue(
          type: ScriptImportIssueType.unsupportedHomebrewDefinition,
          message:
              'Character definitions are not supported yet. Map this entry manually.',
          roleIndex: index,
          sourceId: sourceId,
        ),
      );
    }
    final candidates = canonicalByRoleId[sourceId] ?? const <Character>[];
    if (candidates.isEmpty) {
      return ImportedScriptRole(
        index: index,
        sourceId: sourceId,
        issue: ScriptImportIssue(
          type: ScriptImportIssueType.unknownRoleId,
          message: 'No canonical role matches "$sourceId".',
          roleIndex: index,
          sourceId: sourceId,
        ),
      );
    }
    if (candidates.length > 1) {
      return ImportedScriptRole(
        index: index,
        sourceId: sourceId,
        issue: ScriptImportIssue(
          type: ScriptImportIssueType.ambiguousRoleId,
          message: 'More than one canonical role matches "$sourceId".',
          roleIndex: index,
          sourceId: sourceId,
          candidateRoleIds: candidates.map((role) => role.roleId).toList(),
        ),
      );
    }
    return ImportedScriptRole(
      index: index,
      sourceId: sourceId,
      resolvedRoleId: candidates.single.roleId,
    );
  }

  bool _containsHomebrewDefinition(Map<dynamic, dynamic> entry) {
    const definitionFields = {
      'name',
      'ability',
      'team',
      'edition',
      'firstNight',
      'otherNight',
      'firstNightReminder',
      'otherNightReminder',
      'reminders',
      'setup',
    };
    return entry.keys.any(
      (key) => key is String && definitionFields.contains(key),
    );
  }

  String _newImportedScriptId() {
    final base = 'custom:import-${DateTime.now().microsecondsSinceEpoch}';
    var candidate = base;
    var suffix = 1;
    while (scripts.any((script) => script.id == candidate)) {
      candidate = '$base-$suffix';
      suffix++;
    }
    return candidate;
  }

  Future<void> _saveScripts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scriptsStorageKey,
      _customScripts.map((script) => jsonEncode(script.toJson())).toList(),
    );
  }

  void _loadComplexityOverrides(String? encoded) {
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        if (!standardScripts.any((script) => script.id == entry.key) ||
            entry.value is! Map<String, dynamic>) {
          continue;
        }
        final data = entry.value as Map<String, dynamic>;
        final storyteller = data['storytellerComplexity'];
        final player = data['playerComplexity'];
        if ((storyteller != null && storyteller is! num) ||
            (player != null && player is! num)) {
          continue;
        }
        final value = _ScriptComplexities(
          storyteller: (storyteller as num?)?.toDouble(),
          player: (player as num?)?.toDouble(),
        );
        BotcScript.validateComplexity(
            value.storyteller, 'storytellerComplexity');
        BotcScript.validateComplexity(value.player, 'playerComplexity');
        _standardComplexityOverrides[entry.key] = value;
      }
    } on FormatException {
      // Ignore malformed historic local overrides.
    } on ArgumentError {
      // Ignore out-of-range historic local overrides.
    }
  }

  Future<void> _saveComplexityOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _complexityOverridesStorageKey,
      jsonEncode({
        for (final entry in _standardComplexityOverrides.entries)
          entry.key: {
            'storytellerComplexity': entry.value.storyteller,
            'playerComplexity': entry.value.player,
          },
      }),
    );
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedScriptStorageKey, _selectedScriptId);
  }

  void _validateCustomScript(BotcScript script) {
    if (standardScripts.any((standard) => standard.id == script.id)) {
      throw ArgumentError.value(script.id, 'id', 'Reserved standard script ID');
    }
    if (script.id.trim().isEmpty || script.name.trim().isEmpty) {
      throw ArgumentError('Script ID and name must not be empty');
    }
    if (script.roleIds.any((roleId) => roleId.trim().isEmpty) ||
        script.roleIds.toSet().length != script.roleIds.length) {
      throw ArgumentError('Role IDs must be non-empty and unique');
    }
  }

  static String idForGameset(Gameset gameset) => switch (gameset) {
        Gameset.trouble_brewing => troubleBrewingId,
        Gameset.sects_and_violets => sectsAndVioletsId,
        Gameset.bad_moon_rising => badMoonRisingId,
        Gameset.experimental => experimentalId,
        Gameset.any => troubleBrewingId,
      };

  static String _scriptIdForLegacyGameset(String? value) => switch (value) {
        'Gameset.sects_and_violets' => sectsAndVioletsId,
        'Gameset.bad_moon_rising' => badMoonRisingId,
        'Gameset.experimental' => experimentalId,
        _ => troubleBrewingId,
      };
}

class _ScriptComplexities {
  const _ScriptComplexities({this.storyteller, this.player});

  final double? storyteller;
  final double? player;
}

class _ImportStructure {
  final Map<String, dynamic>? meta;
  final List<dynamic> roles;
  final bool hasDuplicateMeta;
  final bool hasInvalidMeta;

  const _ImportStructure({
    this.meta,
    required this.roles,
    this.hasDuplicateMeta = false,
    this.hasInvalidMeta = false,
  });
}
