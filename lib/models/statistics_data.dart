/// Aggregated, anonymous statistics only. No individual game documents
/// need to be downloaded by the statistics dashboard.
int _count(Object? value) {
  if (value is! num || !value.isFinite || value < 0) return 0;
  return value.toInt();
}

class StatisticsTotals {
  final int games, demoGames, goodWins, evilWins, totalDurationMs,
      totalPlayers, totalDays, totalNights, totalDayDurationMs,
      totalNightDurationMs, deaths, revivals;

  const StatisticsTotals({
    required this.games,
    required this.demoGames,
    required this.goodWins,
    required this.evilWins,
    required this.totalDurationMs,
    required this.totalPlayers,
    required this.totalDays,
    required this.totalNights,
    required this.totalDayDurationMs,
    required this.totalNightDurationMs,
    required this.deaths,
    required this.revivals,
  });

  factory StatisticsTotals.fromMap(Map<String, dynamic> value) {
    return StatisticsTotals(
      games: _count(value['games']),
      demoGames: _count(value['demoGames']),
      goodWins: _count(value['goodWins']),
      evilWins: _count(value['evilWins']),
      totalDurationMs: _count(value['totalDurationMs']),
      totalPlayers: _count(value['totalPlayers']),
      totalDays: _count(value['totalDays']),
      totalNights: _count(value['totalNights']),
      totalDayDurationMs: _count(value['totalDayDurationMs']),
      totalNightDurationMs: _count(value['totalNightDurationMs']),
      deaths: _count(value['deaths']),
      revivals: _count(value['revivals']),
    );
  }

  double get averageDurationMinutes =>
      games == 0 ? 0 : totalDurationMs / games / 60000;
  double get averagePlayers => games == 0 ? 0 : totalPlayers / games;
  double get averageDays => games == 0 ? 0 : totalDays / games;
  double get averageNights => games == 0 ? 0 : totalNights / games;
  double get averageDayMinutes =>
      totalDays == 0 ? 0 : totalDayDurationMs / totalDays / 60000;
  double get averageNightMinutes =>
      totalNights == 0 ? 0 : totalNightDurationMs / totalNights / 60000;
  double get goodWinRate => games == 0 ? 0 : goodWins / games * 100;
}

class StatisticsRole {
  final String id;
  final int appearances, wins, losses, demoAppearances, roleChanges,
      totalDurationMs;

  const StatisticsRole({
    required this.id,
    required this.appearances,
    required this.wins,
    required this.losses,
    required this.demoAppearances,
    required this.roleChanges,
    required this.totalDurationMs,
  });

  factory StatisticsRole.fromMap(String id, Map<String, dynamic> json) =>
      StatisticsRole(
        id: id,
        appearances: _count(json['appearances']),
        wins: _count(json['wins']),
        losses: _count(json['losses']),
        demoAppearances: _count(json['demoAppearances']),
        roleChanges: _count(json['roleChanges']),
        totalDurationMs: _count(json['totalDurationMs']),
      );

  double get winRate =>
      appearances == 0 ? 0 : wins / appearances * 100;
  double get averageMinutes =>
      appearances == 0 ? 0 : totalDurationMs / appearances / 60000;
}

class StatisticsScript {
  final String hash, scriptId, name;
  final bool isCustom;
  final int roleCount;
  final StatisticsTotals totals;

  const StatisticsScript({
    required this.hash,
    required this.scriptId,
    required this.name,
    required this.isCustom,
    required this.roleCount,
    required this.totals,
  });

  factory StatisticsScript.fromMap(
      String hash, Map<String, dynamic> json) =>
      StatisticsScript(
        hash: hash,
        scriptId: json['scriptId'] is String ? json['scriptId'] as String : '',
        name: json['name'] is String && (json['name'] as String).trim().isNotEmpty
            ? json['name'] as String
            : hash.substring(0, hash.length < 8 ? hash.length : 8),
        isCustom: json['isCustom'] == true,
        roleCount: _count(json['roleCount']),
        totals: StatisticsTotals.fromMap(json),
      );
}
