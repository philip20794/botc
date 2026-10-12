enum ChronicleInputType {
  number,
  yesNo,
  player,
  players,
  character,
  characters,
  choice,
  text,
  form,
}

class ChronicleChoiceOption {
  final String value;
  final String label;

  const ChronicleChoiceOption({required this.value, required this.label});

  static ChronicleChoiceOption? fromJson(dynamic json) {
    if (json is! Map || json['value'] is! String) return null;
    final value = json['value'] as String;
    if (value.isEmpty) return null;
    return ChronicleChoiceOption(
      value: value,
      label: json['label'] is String ? json['label'] as String : value,
    );
  }

  Map<String, dynamic> toJson() => {'value': value, 'label': label};
}

class ChronicleInputDefinition {
  final String id;
  final ChronicleInputType type;
  final String label;
  final int? min;
  final int? max;
  final int? minCount;
  final int? maxCount;
  final List<ChronicleChoiceOption> options;
  final List<ChronicleInputDefinition> fields;
  final bool onlyIfApplicable;
  final int? night;
  final bool repeatable;

  const ChronicleInputDefinition({
    required this.id,
    required this.type,
    required this.label,
    this.min,
    this.max,
    this.minCount,
    this.maxCount,
    this.options = const [],
    this.fields = const [],
    this.onlyIfApplicable = false,
    this.night,
    this.repeatable = false,
  });

  static ChronicleInputDefinition? fromJson(dynamic json) {
    if (json is! Map || json['id'] is! String || json['type'] is! String) {
      return null;
    }
    final id = (json['id'] as String).trim();
    if (id.isEmpty) return null;
    final type = switch (json['type']) {
      'number' => ChronicleInputType.number,
      'yesNo' => ChronicleInputType.yesNo,
      'player' => ChronicleInputType.player,
      'players' => ChronicleInputType.players,
      'character' => ChronicleInputType.character,
      'characters' => ChronicleInputType.characters,
      'choice' => ChronicleInputType.choice,
      'text' => ChronicleInputType.text,
      'form' => ChronicleInputType.form,
      _ => null,
    };
    if (type == null) return null;

    final exactCount = _positiveInt(json['count']);
    final minCount = exactCount ?? _nonNegativeInt(json['minCount']);
    final maxCount = exactCount ?? _positiveInt(json['maxCount']);
    if (minCount != null && maxCount != null && minCount > maxCount) {
      return null;
    }
    final min = _int(json['min']);
    final max = _int(json['max']);
    if (min != null && max != null && min > max) return null;

    final options =
        (json['options'] is List ? json['options'] as List : const [])
            .map(ChronicleChoiceOption.fromJson)
            .whereType<ChronicleChoiceOption>()
            .toList(growable: false);
    final fields = (json['fields'] is List ? json['fields'] as List : const [])
        .map(ChronicleInputDefinition.fromJson)
        .whereType<ChronicleInputDefinition>()
        .toList(growable: false);
    if (type == ChronicleInputType.choice && options.isEmpty) return null;
    if (type == ChronicleInputType.form && fields.isEmpty) return null;

    return ChronicleInputDefinition(
      id: id,
      type: type,
      label: json['label'] is String ? json['label'] as String : id,
      min: min,
      max: max,
      minCount: minCount,
      maxCount: maxCount,
      options: options,
      fields: fields,
      onlyIfApplicable: json['when'] == 'onlyIfApplicable',
      night: _positiveInt(json['night']),
      repeatable: json['repeatable'] == true,
    );
  }

  static int? _int(dynamic value) => value is num ? value.toInt() : null;

  static int? _positiveInt(dynamic value) {
    final parsed = _int(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static int? _nonNegativeInt(dynamic value) {
    final parsed = _int(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  bool appliesToNight(int round) => night == null || night == round;

  int get effectiveMinCount {
    if (type == ChronicleInputType.player ||
        type == ChronicleInputType.character) {
      return 1;
    }
    return minCount ?? 0;
  }

  int? get effectiveMaxCount {
    if (type == ChronicleInputType.player ||
        type == ChronicleInputType.character) {
      return 1;
    }
    return maxCount;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (minCount != null && minCount == maxCount) 'count': minCount,
        if (minCount != null && minCount != maxCount) 'minCount': minCount,
        if (maxCount != null && minCount != maxCount) 'maxCount': maxCount,
        if (options.isNotEmpty)
          'options': options.map((option) => option.toJson()).toList(),
        if (fields.isNotEmpty)
          'fields': fields.map((field) => field.toJson()).toList(),
        if (onlyIfApplicable) 'when': 'onlyIfApplicable',
        if (night != null) 'night': night,
        if (repeatable) 'repeatable': true,
      };
}

class ChronicleSchema {
  final List<String> auto;
  final List<ChronicleInputDefinition> firstNight;
  final List<ChronicleInputDefinition> otherNights;

  const ChronicleSchema({
    this.auto = const [],
    this.firstNight = const [],
    this.otherNights = const [],
  });

  static ChronicleSchema? fromJson(dynamic json) {
    if (json is! Map) return null;

    // Backward compatibility for the initial single-input draft.
    if (json['input'] is Map) {
      final input = Map<String, dynamic>.from(json['input'] as Map);
      input.putIfAbsent('id', () => 'legacyInput');
      input.putIfAbsent('label', () => 'Information');
      if (input['type'] == 'playersAndYesNo') {
        final playerCount = input['playerCount'] is num
            ? (input['playerCount'] as num).toInt()
            : 2;
        input
          ..['type'] = 'form'
          ..['fields'] = [
            {
              'id': 'chosenPlayers',
              'type': 'players',
              'label': 'Players',
              'count': playerCount,
            },
            {
              'id': 'answer',
              'type': 'yesNo',
              'label': 'Answer',
            },
          ];
      }
      final definition = ChronicleInputDefinition.fromJson(input);
      return definition == null
          ? null
          : ChronicleSchema(
              auto: const ['nightStep'],
              firstNight: [definition],
              otherNights: [definition],
            );
    }

    final auto = (json['auto'] is List ? json['auto'] as List : const [])
        .whereType<String>()
        .toList(growable: false);
    final firstNight = _definitions(json['firstNight']);
    final otherNights = _definitions(json['otherNights']);
    if (auto.isEmpty && firstNight.isEmpty && otherNights.isEmpty) return null;
    return ChronicleSchema(
      auto: auto,
      firstNight: firstNight,
      otherNights: otherNights,
    );
  }

  static List<ChronicleInputDefinition> _definitions(dynamic value) =>
      (value is List ? value : const [])
          .map(ChronicleInputDefinition.fromJson)
          .whereType<ChronicleInputDefinition>()
          .toList(growable: false);

  List<ChronicleInputDefinition> definitionsForNight(int round) =>
      (round == 1 ? firstNight : otherNights)
          .where((definition) => definition.appliesToNight(round))
          .toList(growable: false);

  bool get recordsNightStep => auto.contains('nightStep');
  bool get recordsQuickFlow => auto.contains('quickFlow');

  Map<String, dynamic> toJson() => {
        'auto': auto,
        if (firstNight.isNotEmpty)
          'firstNight': firstNight.map((item) => item.toJson()).toList(),
        if (otherNights.isNotEmpty)
          'otherNights': otherNights.map((item) => item.toJson()).toList(),
      };
}
