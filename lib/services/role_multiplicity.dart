import 'dart:math';

/// Setup multiplicities are role rules, not hard-coded catalog token counts.
///
/// Riot starts as ONE Demon; Minions turn into Riot on the third night/day.
/// Farmer starts as ONE Townsfolk; later conversions are actual role changes.
abstract final class RoleMultiplicity {
  // Only roles with a meaningful setup badge belong here.
  // Farmer starts once; later copies are created during play.
  static const trackedRoles = {
    'villageidiot',
    'legion',
    'riot',
  };

  static bool storytellerChooses(String roleId) =>
      roleId == 'villageidiot' || roleId == 'legion';

  static List<int> allowedCounts(
    String roleId,
    int playerCount, {
    int? availableSlots,
  }) {
    final maxCount = switch (roleId) {
      'villageidiot' => 3,
      'legion' => max(0, playerCount - 1),
      _ => 1,
    };
    final minCount = roleId == 'legion' ? (playerCount ~/ 2) + 1 : 1;
    if (playerCount < 5 || maxCount < minCount) return const [];
    return [
      for (var n = minCount; n <= maxCount; n++)
        if (availableSlots == null || n <= availableSlots) n,
    ];
  }

  static int randomCount(
    String roleId,
    int playerCount, {
    int? availableSlots,
    Random? random,
  }) {
    final allowed =
        allowedCounts(roleId, playerCount, availableSlots: availableSlots);
    if (allowed.isEmpty) {
      throw StateError('No valid $roleId count for $playerCount players');
    }
    return allowed[(random ?? Random()).nextInt(allowed.length)];
  }

  static int automaticCount(String roleId) => 1;
}
