class BotcScript {
  final String id;
  final String name;
  final String? author;
  final List<String> roleIds;
  final double? storytellerComplexity;
  final double? playerComplexity;

  BotcScript({
    required this.id,
    required this.name,
    this.author,
    required List<String> roleIds,
    this.storytellerComplexity,
    this.playerComplexity,
  }) : roleIds = List.unmodifiable(roleIds) {
    validateComplexity(storytellerComplexity, 'storytellerComplexity');
    validateComplexity(playerComplexity, 'playerComplexity');
  }

  factory BotcScript.fromJson(Map<String, dynamic> json) {
    return BotcScript(
      id: json['id'] as String,
      name: json['name'] as String,
      author: json['author'] as String?,
      roleIds: (json['roleIds'] as List<dynamic>).cast<String>(),
      storytellerComplexity: _readComplexity(json, 'storytellerComplexity'),
      playerComplexity: _readComplexity(json, 'playerComplexity'),
    );
  }

  BotcScript withComplexities({
    double? storytellerComplexity,
    double? playerComplexity,
  }) {
    return BotcScript(
      id: id,
      name: name,
      author: author,
      roleIds: roleIds,
      storytellerComplexity: storytellerComplexity,
      playerComplexity: playerComplexity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (author != null) 'author': author,
        'roleIds': roleIds,
        if (storytellerComplexity != null)
          'storytellerComplexity': storytellerComplexity,
        if (playerComplexity != null) 'playerComplexity': playerComplexity,
      };

  static double? _readComplexity(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value == null) return null;
    if (value is! num) {
      throw FormatException('$field must be numeric.');
    }
    return value.toDouble();
  }

  static void validateComplexity(double? value, String field) {
    if (value == null) return;
    final halfSteps = value * 2;
    if (!value.isFinite ||
        value < 0 ||
        value > 5 ||
        (halfSteps - halfSteps.round()).abs() > 0.000001) {
      throw ArgumentError.value(
        value,
        field,
        'Must be between 0 and 5 in increments of 0.5.',
      );
    }
  }
}
