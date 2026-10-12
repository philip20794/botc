import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';

/// The optional Chronicle data that can be entered while one character's
/// night step is active. Values are stored in the Chronicle itself, so this
/// object is only a read-only projection for the playground.
class ActiveNightChronicleInput {
  final Character owner;
  final ChronicleInputDefinition definition;
  final String? eventId;
  final Map<String, dynamic> values;

  const ActiveNightChronicleInput({
    required this.owner,
    required this.definition,
    required this.eventId,
    required this.values,
  });

  List<ChronicleInputDefinition> get fields => flattenFields(definition);

  List<ChronicleInputDefinition> get playerFields => fields
      .where((field) =>
          field.type == ChronicleInputType.player ||
          field.type == ChronicleInputType.players)
      .toList(growable: false);

  bool get hasPlayerField => playerFields.isNotEmpty;

  /// Selects the first field that still has capacity. Tapping a selected
  /// player always addresses the field that already contains that player.
  ChronicleInputDefinition? playerFieldFor(String characterId) {
    for (final field in playerFields) {
      if (selectedPlayerIds(field).contains(characterId)) return field;
    }
    for (final field in playerFields) {
      final maximum = field.effectiveMaxCount;
      if (maximum == null || selectedPlayerIds(field).length < maximum) {
        return field;
      }
    }
    return playerFields.isEmpty ? null : playerFields.last;
  }

  List<ChronicleInputDefinition> get yesNoFields => fields
      .where((field) => field.type == ChronicleInputType.yesNo)
      .toList(growable: false);

  List<ChronicleInputDefinition> get numberFields => fields
      .where((field) => field.type == ChronicleInputType.number)
      .toList(growable: false);

  Set<String> selectedPlayerIds(ChronicleInputDefinition field) {
    final raw = values[field.id];
    final items = field.type == ChronicleInputType.players
        ? (raw is List ? raw : const [])
        : [if (raw is Map) raw];
    return items
        .whereType<Map>()
        .map((item) => item['characterId'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Set<String> get selectedPlayerIdsForAllFields =>
      playerFields.expand(selectedPlayerIds).toSet();

  static List<ChronicleInputDefinition> flattenFields(
    ChronicleInputDefinition definition,
  ) {
    if (definition.type != ChronicleInputType.form) return [definition];
    return definition.fields.expand(flattenFields).toList(growable: false);
  }
}
