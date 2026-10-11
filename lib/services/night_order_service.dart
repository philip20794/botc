import 'dart:convert';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NightStepKind { phase, character }

@immutable
class NightStep {
  final String id;
  final String orderId;
  final NightStepKind kind;
  final String? roleId;
  final String? characterInstanceId;

  const NightStep._({
    required this.id,
    required this.orderId,
    required this.kind,
    this.roleId,
    this.characterInstanceId,
  });

  factory NightStep.phase(String phaseId) => NightStep._(
        id: 'phase:$phaseId',
        orderId: phaseId,
        kind: NightStepKind.phase,
      );

  factory NightStep.character(Character character) => NightStep._(
        id: 'role:${character.roleId}:${character.id}',
        orderId: character.roleId,
        kind: NightStepKind.character,
        roleId: character.roleId,
        characterInstanceId: character.id,
      );
}

class _NightCatalogEntry {
  final String name;
  final String? firstNight;
  final String? otherNight;

  const _NightCatalogEntry({
    required this.name,
    this.firstNight,
    this.otherNight,
  });
}

/// Loads the canonical cross-edition night order and localized instructions.
///
/// The order is technical data and always comes from order.json. Character
/// instances are only used to decide which canonical role steps are present.
class NightOrderService extends ChangeNotifier {
  final AssetBundle _bundle;
  late final Future<void> ready;
  bool _isReady = false;

  List<String> _firstNightOrder = const [];
  List<String> _otherNightOrder = const [];
  Map<String, Map<String, String>> _phaseInstructions = const {};
  Map<String, _NightCatalogEntry> _englishCatalog = const {};
  Map<String, _NightCatalogEntry> _germanCatalog = const {};

  NightOrderService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle {
    ready = _load();
  }

  List<String> get firstNightOrder => List.unmodifiable(_firstNightOrder);
  List<String> get otherNightOrder => List.unmodifiable(_otherNightOrder);
  Set<String> get phaseIds => _phaseInstructions.keys.toSet();
  bool get isReady => _isReady;

  Future<void> _load() async {
    final rawValues = await Future.wait([
      _bundle.loadString('assets/night_order/order.json'),
      _bundle.loadString('assets/characters/en.json'),
      _bundle.loadString('assets/characters/de.json'),
    ]);
    final order = jsonDecode(rawValues[0]) as Map<String, dynamic>;
    _firstNightOrder = _stringList(order['firstNight']);
    _otherNightOrder = _stringList(order['otherNight']);
    _phaseInstructions = _readPhaseInstructions(order['phaseInstructions']);
    _englishCatalog = _readCatalog(rawValues[1]);
    _germanCatalog = _readCatalog(rawValues[2]);
    _isReady = true;
    notifyListeners();
  }

  List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  Map<String, Map<String, String>> _readPhaseInstructions(Object? value) {
    if (value is! Map<String, dynamic>) return const {};
    return value.map((phaseId, localized) {
      final values = localized is Map<String, dynamic>
          ? localized.map((key, text) => MapEntry(key, text.toString()))
          : <String, String>{};
      return MapEntry(phaseId, values);
    });
  }

  Map<String, _NightCatalogEntry> _readCatalog(String raw) {
    final entries = jsonDecode(raw) as List<dynamic>;
    final result = <String, _NightCatalogEntry>{};
    for (final value in entries.whereType<Map<String, dynamic>>()) {
      final roleId = value['roleId'];
      if (roleId is! String || roleId.isEmpty) continue;
      final instructions = value['nightInstructions'];
      final instructionMap =
          instructions is Map<String, dynamic> ? instructions : const {};
      result[roleId] = _NightCatalogEntry(
        name: value['name'] is String ? value['name'] as String : roleId,
        firstNight: instructionMap['firstNight'] as String?,
        otherNight: instructionMap['otherNight'] as String?,
      );
    }
    return result;
  }

  List<NightStep> stepsFor({
    required int nightCount,
    required List<Character> gameCharacters,
    required int regularPlayerCount,
    required bool Function(Character character) isAlive,
  }) {
    if (nightCount < 1) return const [];
    final order = nightCount == 1 ? _firstNightOrder : _otherNightOrder;
    final byRoleId = <String, List<Character>>{};
    for (final character in gameCharacters) {
      byRoleId.putIfAbsent(character.roleId, () => []).add(character);
    }

    final livingPoppyGrower = (byRoleId['poppygrower'] ?? const <Character>[])
        .any((character) => isAlive(character));
    final showInitialTeamInfo = regularPlayerCount >= 7 && !livingPoppyGrower;
    final steps = <NightStep>[];
    for (final orderId in order) {
      if (_phaseInstructions.containsKey(orderId)) {
        if ((orderId == 'minioninfo' || orderId == 'demoninfo') &&
            !showInitialTeamInfo) {
          continue;
        }
        steps.add(NightStep.phase(orderId));
        continue;
      }
      for (final character in byRoleId[orderId] ?? const <Character>[]) {
        // Do not filter dead characters here: several conditional abilities
        // act because a character died or can interact with dead players.
        steps.add(NightStep.character(character));
      }
    }
    return steps;
  }

  int orderIndexForStep(String stepId, int nightCount) {
    final orderId = orderIdFromStepId(stepId);
    final order = nightCount == 1 ? _firstNightOrder : _otherNightOrder;
    return order.indexOf(orderId);
  }

  String orderIdFromStepId(String stepId) {
    if (stepId.startsWith('phase:')) return stepId.substring(6);
    if (stepId.startsWith('role:')) {
      final separator = stepId.indexOf(':', 5);
      return separator < 0
          ? stepId.substring(5)
          : stepId.substring(5, separator);
    }
    return stepId;
  }

  String titleFor(NightStep step, String languageCode) {
    if (step.kind == NightStepKind.phase) {
      const titles = {
        'dusk': {'en': 'Dusk', 'de': 'Abenddämmerung'},
        'dawn': {'en': 'Dawn', 'de': 'Morgengrauen'},
        'minioninfo': {'en': 'Minion Info', 'de': 'Minion-Information'},
        'demoninfo': {'en': 'Demon Info', 'de': 'Dämonen-Information'},
      };
      return titles[step.orderId]?[languageCode] ??
          titles[step.orderId]?['en'] ??
          step.orderId;
    }
    return _localizedEntry(step.roleId!, languageCode)?.name ?? step.roleId!;
  }

  String instructionFor(NightStep step, int nightCount, String languageCode) {
    if (step.kind == NightStepKind.phase) {
      final values = _phaseInstructions[step.orderId] ?? const {};
      return _nonEmpty(values[languageCode]) ?? _nonEmpty(values['en']) ?? '';
    }
    final localized = _localizedEntry(step.roleId!, languageCode);
    final english = _englishCatalog[step.roleId!];
    final localizedText =
        nightCount == 1 ? localized?.firstNight : localized?.otherNight;
    final englishText =
        nightCount == 1 ? english?.firstNight : english?.otherNight;
    return _nonEmpty(localizedText) ?? _nonEmpty(englishText) ?? '';
  }

  _NightCatalogEntry? _localizedEntry(String roleId, String languageCode) {
    if (languageCode != 'de') return _englishCatalog[roleId];
    final german = _germanCatalog[roleId];
    final english = _englishCatalog[roleId];
    if (german == null) return english;
    return _NightCatalogEntry(
      name: _nonEmpty(german.name) ?? english?.name ?? roleId,
      firstNight:
          _nonEmpty(german.firstNight) ?? _nonEmpty(english?.firstNight),
      otherNight:
          _nonEmpty(german.otherNight) ?? _nonEmpty(english?.otherNight),
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  List<String> validateData() {
    final errors = <String>[];
    const requiredPhases = <String>{
      'dusk',
      'minioninfo',
      'demoninfo',
      'dawn',
    };
    for (final phaseId in requiredPhases) {
      final instructions = _phaseInstructions[phaseId];
      if (instructions == null) {
        errors.add('phaseInstructions: missing $phaseId');
      } else if (_nonEmpty(instructions['en']) == null) {
        errors.add('phaseInstructions: missing English text for $phaseId');
      }
    }
    for (final entry in {
      'firstNight': _firstNightOrder,
      'otherNight': _otherNightOrder,
    }.entries) {
      if (entry.value.isEmpty) errors.add('${entry.key}: empty order');
      final seen = <String>{};
      for (final id in entry.value) {
        if (!seen.add(id)) errors.add('${entry.key}: duplicate $id');
        if (!_phaseInstructions.containsKey(id) &&
            !_englishCatalog.containsKey(id)) {
          errors.add('${entry.key}: unknown role $id');
          continue;
        }
        final catalogEntry = _englishCatalog[id];
        if (catalogEntry != null) {
          final instruction = entry.key == 'firstNight'
              ? catalogEntry.firstNight
              : catalogEntry.otherNight;
          if (_nonEmpty(instruction) == null) {
            errors.add('${entry.key}: missing instruction for $id');
          }
        }
      }
    }
    return errors;
  }
}
