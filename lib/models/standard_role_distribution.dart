/// Base game setup counts, before any character setup abilities are applied.
/// Counts cover 5-15 regular characters. At 16+ players the extra players
/// are Travellers, so the four regular character counts stay at 15 players.
class StandardRoleDistribution {
  const StandardRoleDistribution({
    required this.townsfolk,
    required this.outsiders,
    required this.minions,
    required this.demons,
  });

  final int townsfolk;
  final int outsiders;
  final int minions;
  final int demons;

  static const _standardCounts = <int, StandardRoleDistribution>{
    5: StandardRoleDistribution(townsfolk: 3, outsiders: 0, minions: 1, demons: 1),
    6: StandardRoleDistribution(townsfolk: 3, outsiders: 1, minions: 1, demons: 1),
    7: StandardRoleDistribution(townsfolk: 5, outsiders: 0, minions: 1, demons: 1),
    8: StandardRoleDistribution(townsfolk: 5, outsiders: 1, minions: 1, demons: 1),
    9: StandardRoleDistribution(townsfolk: 5, outsiders: 2, minions: 1, demons: 1),
    10: StandardRoleDistribution(townsfolk: 7, outsiders: 0, minions: 2, demons: 1),
    11: StandardRoleDistribution(townsfolk: 7, outsiders: 1, minions: 2, demons: 1),
    12: StandardRoleDistribution(townsfolk: 7, outsiders: 2, minions: 2, demons: 1),
    13: StandardRoleDistribution(townsfolk: 9, outsiders: 0, minions: 3, demons: 1),
    14: StandardRoleDistribution(townsfolk: 9, outsiders: 1, minions: 3, demons: 1),
    15: StandardRoleDistribution(townsfolk: 9, outsiders: 2, minions: 3, demons: 1),
  };

  static StandardRoleDistribution? forPlayerCount(int playerCount) {
    if (playerCount < 5) return null;
    return _standardCounts[playerCount > 15 ? 15 : playerCount];
  }
}
