import 'dart:convert';

import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/grimoire_ui.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/statistics_data.dart';
import 'package:blood_on_the_clocktower/services/statistics_repository.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const _good = Color(0xFF638BB8);
const _evil = Color(0xFFC0556C);
enum _Sort { usage, winRate, wins, name }

/// Global, read-only statistics built from server-side aggregated documents.
/// The application never downloads individual public game records to render UI.
class StatisticsScreen extends StatefulWidget {
  final StatisticsRepository? repository;
  const StatisticsScreen({super.key, this.repository});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final StatisticsRepository _repository;
  Future<StatisticsTotals?>? _global;
  Future<List<StatisticsRole>>? _roles;
  Future<List<StatisticsScript>>? _scripts;
  Future<Map<String, String>>? _names;
  String? _language;
  String _query = '';
  _Sort _sort = _Sort.usage;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CloudStatisticsRepository();
    _global = _scheduled(_repository.loadOverview);
  }

  // Defer repository calls until after FutureBuilder can subscribe.
  // This also makes immediate offline failures safe during widget tests.
  Future<T> _scheduled<T>(Future<T> Function() load) async {
    await Future<void>.delayed(Duration.zero);
    return load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language != language) {
      _language = language;
      _names = _loadNames(language);
    }
  }

  Future<Map<String, String>> _loadNames(String language) async {
    try {
      final text = await rootBundle.loadString(
        'assets/characters/' + (language == 'de' ? 'de' : 'en') + '.json',
      );
      final values = jsonDecode(text) as List<dynamic>;
      return {
        for (final entry in values)
          if (entry is Map<String, dynamic> &&
              entry['name'] is String &&
              (entry['roleId'] is String || entry['image'] is String))
            (entry['roleId'] is String
                ? entry['roleId'] as String
                : (entry['image'] as String).replaceFirst('Icon_', '')):
                entry['name'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  void _selectTab(int tab) {
    setState(() {
      _tab = tab;
      if (tab == 1) _roles ??= _scheduled(_repository.loadRoles);
      if (tab == 2) _scripts ??= _scheduled(_repository.loadScripts);
    });
  }

  void _refresh() {
    setState(() {
      if (_tab == 1) {
        _roles = _scheduled(_repository.loadRoles);
      } else if (_tab == 2) {
        _scripts = _scheduled(_repository.loadScripts);
      } else {
        _global = _scheduled(_repository.loadOverview);
      }
    });
  }

  String _number(BuildContext context, int n) =>
      NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode)
          .format(n);

  String _decimal(BuildContext context, double n) =>
      NumberFormat.decimalPatternDigits(
        locale: Localizations.localeOf(context).languageCode,
        decimalDigits: 1,
      ).format(n);

  String _minutes(double value, AppLocalizations s) {
    final minutes = value.round();
    if (minutes >= 60) {
      return (minutes ~/ 60).toString() + ' h ' +
          (minutes % 60).toString() + ' ' + s.statsMinutes;
    }
    return minutes.toString() + ' ' + s.statsMinutes;
  }

  Widget _metric(BuildContext context, String label, String value,
      IconData icon) => Expanded(child: GrimoirePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 21, color: GrimoireColors.antiqueGold),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold, color: GrimoireColors.ivory)),
          const SizedBox(height: 4),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GrimoireColors.secondaryText, fontSize: 12)),
        ]),
      ));

  Widget _metrics(BuildContext context,
      String labelA, String valueA, IconData iconA,
      String labelB, String valueB, IconData iconB) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _metric(context, labelA, valueA, iconA),
        const SizedBox(width: 10),
        _metric(context, labelB, valueB, iconB),
      ]);

  Widget _demoNotice(BuildContext context, int count) {
    if (count <= 0) return const SizedBox.shrink();
    final s = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GrimoirePanel(child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined,
            color: GrimoireColors.antiqueGold),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.statsDemoGames + ': ' + _number(context, count),
                style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(s.statsDemoNotice, style: const TextStyle(
                color: GrimoireColors.secondaryText, fontSize: 12)),
            ],
          )),
        ],
      )),
    );
  }

  Widget _wins(BuildContext context, StatisticsTotals values) {
    final s = AppLocalizations.of(context)!;
    final total = values.goodWins + values.evilWins;
    final ratio = total == 0 ? 0.5 : values.goodWins / total;
    return GrimoirePanel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrimoireSectionHeading(title: s.statsVictories,
          icon: Icons.balance_outlined),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(12),
          child: SizedBox(height: 15, child: Row(children: [
            if (ratio > 0) Expanded(flex: (ratio * 1000).round(),
              child: Container(color: _good)),
            if (ratio < 1) Expanded(flex: ((1 - ratio) * 1000).round(),
              child: Container(color: _evil)),
          ]))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(s.goodTeam + ': ' +
            _number(context, values.goodWins) + ' (' +
            _decimal(context, total == 0 ? 0 : ratio * 100) + '%)',
            style: const TextStyle(color: _good, fontSize: 12))),
          Flexible(child: Text(s.evilTeam + ': ' +
            _number(context, values.evilWins),
            style: const TextStyle(color: _evil, fontSize: 12))),
        ]),
      ],
    ));
  }

  Widget _empty(BuildContext context, String text, {bool error = false}) {
    final s = AppLocalizations.of(context)!;
    return GrimoirePanel(emphasized: true,
      child: Column(children: [
        Icon(error ? Icons.cloud_off_outlined : Icons.hourglass_empty,
          size: 34, color: GrimoireColors.antiqueGold),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center,
          style: const TextStyle(color: GrimoireColors.secondaryText)),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: _refresh,
          icon: const Icon(Icons.refresh), label: Text(s.statsRetry)),
      ]),
    );
  }

  Widget _summary(BuildContext context, StatisticsTotals totals,
      {required bool history}) {
    final s = AppLocalizations.of(context)!;
    if (history) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _demoNotice(context, totals.demoGames),
        GrimoireSectionHeading(title: s.statsHistory,
          icon: Icons.timeline_outlined),
        const SizedBox(height: 12),
        _metrics(context, s.statsAvgDays, _decimal(context, totals.averageDays),
          Icons.wb_sunny_outlined, s.statsAvgNights,
          _decimal(context, totals.averageNights), Icons.nights_stay_outlined),
        const SizedBox(height: 12),
        _metrics(context, s.statsDayDuration,
          _minutes(totals.averageDayMinutes, s), Icons.wb_sunny_outlined,
          s.statsNightDuration, _minutes(totals.averageNightMinutes, s),
          Icons.nights_stay_outlined),
        const SizedBox(height: 12),
        _metrics(context, s.statsDeaths, _number(context, totals.deaths),
          Icons.heart_broken_outlined, s.statsRevivals,
          _number(context, totals.revivals), Icons.favorite_border),
        const SizedBox(height: 14),
        GrimoirePanel(child: Text(s.statsChronicleNote,
          style: const TextStyle(
            color: GrimoireColors.secondaryText, fontSize: 12))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _demoNotice(context, totals.demoGames),
      GrimoirePanel(emphasized: true, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          GrimoireSectionHeading(title: s.statsGlobal,
            icon: Icons.auto_graph_outlined),
          const SizedBox(height: 8),
          Text(_number(context, totals.games),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: GrimoireColors.antiqueGold)),
          Text(s.statsGames, style: const TextStyle(
            color: GrimoireColors.secondaryText)),
        ],
      )),
      const SizedBox(height: 12),
      _metrics(context, s.statsAvgDuration,
        _minutes(totals.averageDurationMinutes, s), Icons.schedule_outlined,
        s.statsAvgPlayers, _decimal(context, totals.averagePlayers),
        Icons.groups_outlined),
      const SizedBox(height: 12),
      _wins(context, totals),
      const SizedBox(height: 18),
      Text(s.statsAbout, textAlign: TextAlign.center,
        style: const TextStyle(
          color: GrimoireColors.secondaryText, fontSize: 12)),
    ]);
  }

  Widget _globalTab(BuildContext context, {required bool history}) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<StatisticsTotals?>(
      future: _global,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return _empty(context, s.statsError, error: true);
        final totals = snapshot.data;
        if (totals == null || totals.games == 0) {
          return _empty(context, s.statsEmpty);
        }
        return _summary(context, totals, history: history);
      },
    );
  }

  Widget _value(BuildContext context, String label, String text) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(label, style: const TextStyle(
              color: GrimoireColors.secondaryText))),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ));

  void _showDetails(BuildContext context, String title, List<Widget> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(sheetContext).textTheme.titleLarge
                ?.copyWith(color: GrimoireColors.antiqueGold)),
            const SizedBox(height: 12),
            ...items,
          ],
        )),
      )),
    );
  }

  void _roleDetails(BuildContext context, StatisticsRole role, String name) {
    final s = AppLocalizations.of(context)!;
    _showDetails(context, name, [
      _value(context, s.statsAppearances, _number(context, role.appearances)),
      _value(context, s.statsWinRate, _decimal(context, role.winRate) + '%'),
      _value(context, s.statsWins, _number(context, role.wins)),
      _value(context, s.statsLosses, _number(context, role.losses)),
      _value(context, s.statsAvgDuration, _minutes(role.averageMinutes, s)),
      _value(context, s.statsRoleChanges, _number(context, role.roleChanges)),
      if (role.demoAppearances > 0)
        _value(context, s.statsAppearanceDemo,
          _number(context, role.demoAppearances)),
      if (role.appearances < 10)
        Text(s.statsSmallSample, style: const TextStyle(
          fontSize: 12, color: GrimoireColors.antiqueGold)),
      const SizedBox(height: 10),
      Text(s.statsRoleNote, style: const TextStyle(
        fontSize: 12, color: GrimoireColors.secondaryText)),
    ]);
  }

  String _labelForRole(String id, Map<String, String> names) =>
      names[id] ?? (id.isEmpty ? id : id[0].toUpperCase() + id.substring(1));

  List<StatisticsRole> _sortRoles(List<StatisticsRole> values,
      Map<String, String> names) {
    final query = _query.trim().toLowerCase();
    final result = values.where((r) => r.appearances > 0 &&
      _labelForRole(r.id, names).toLowerCase().contains(query)).toList();
    result.sort((a, b) {
      if (_sort == _Sort.name) {
        return _labelForRole(a.id, names).compareTo(_labelForRole(b.id, names));
      }
      if (_sort == _Sort.winRate) {
        final samples = (b.appearances >= 10 ? 1 : 0)
          .compareTo(a.appearances >= 10 ? 1 : 0);
        if (samples != 0) return samples;
        final rates = b.winRate.compareTo(a.winRate);
        if (rates != 0) return rates;
      } else {
        final metric = _sort == _Sort.usage
          ? b.appearances.compareTo(a.appearances)
          : b.wins.compareTo(a.wins);
        if (metric != 0) return metric;
      }
      return b.appearances.compareTo(a.appearances);
    });
    return result;
  }

  Widget _roleTile(BuildContext context, StatisticsRole role,
      String name, int rank) {
    final s = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GrimoirePressablePanel(
        key: ValueKey('stats-role-' + role.id),
        onTap: () => _roleDetails(context, role, name),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          SizedBox(width: 22, child: Text(rank.toString(),
            style: const TextStyle(
              color: GrimoireColors.secondaryText, fontSize: 12))),
          ClipOval(child: Image.asset(
            'assets/images/characters/Icon_' + role.id + '.png',
            width: 42, height: 42, fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => const SizedBox(
              width: 42, height: 42, child: Icon(Icons.auto_awesome,
                color: GrimoireColors.antiqueGold)),
          )),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(s.statsAppearances + ': ' +
                  _number(context, role.appearances),
                style: const TextStyle(
                  fontSize: 12, color: GrimoireColors.secondaryText)),
            ],
          )),
          const SizedBox(width: 4),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_decimal(context, role.winRate) + '%',
              style: const TextStyle(color: GrimoireColors.antiqueGold,
                fontWeight: FontWeight.bold)),
            Text(s.statsWinRate, style: const TextStyle(
              color: GrimoireColors.secondaryText, fontSize: 11)),
          ]),
          const Icon(Icons.chevron_right, size: 18,
            color: GrimoireColors.secondaryText),
        ]),
      ),
    );
  }

  Widget _rolesTab(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<StatisticsRole>>(
      future: _roles,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return _empty(context, s.statsError, error: true);
        final values = snapshot.data ?? [];
        if (values.isEmpty) return _empty(context, s.statsEmptyRoles);
        return FutureBuilder<Map<String, String>>(
          future: _names,
          builder: (context, labels) {
            final names = labels.data ?? {};
            final ranked = _sortRoles(values, names);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GrimoireSectionHeading(title: s.statsCompareRoles,
                  icon: Icons.people_alt_outlined),
                const SizedBox(height: 8),
                Text(s.statsRoleNote, style: const TextStyle(
                  color: GrimoireColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('stats-role-search'),
                  decoration: InputDecoration(
                    hintText: s.statsFindRole,
                    prefixIcon: const Icon(Icons.search)),
                  onChanged: (text) => setState(() => _query = text),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_Sort>(
                  key: const ValueKey('stats-role-sort'),
                  initialValue: _sort,
                  decoration: InputDecoration(labelText: s.statsSortBy,
                    isDense: true),
                  items: [
                    DropdownMenuItem(value: _Sort.usage,
                      child: Text(s.statsSortAppearances)),
                    DropdownMenuItem(value: _Sort.winRate,
                      child: Text(s.statsSortWinRate)),
                    DropdownMenuItem(value: _Sort.wins,
                      child: Text(s.statsSortWins)),
                    DropdownMenuItem(value: _Sort.name,
                      child: Text(s.statsSortName)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
                const SizedBox(height: 14),
                if (ranked.isEmpty) _empty(context, s.statsNoResults)
                else for (var i = 0; i < ranked.length; i++)
                  _roleTile(context, ranked[i],
                    _labelForRole(ranked[i].id, names), i + 1),
              ],
            );
          },
        );
      },
    );
  }

  void _scriptDetails(BuildContext context, StatisticsScript script) {
    final s = AppLocalizations.of(context)!;
    final data = script.totals;
    _showDetails(context, script.name, [
      _value(context, s.statsGames, _number(context, data.games)),
      _value(context, s.statsGoodWins, _number(context, data.goodWins)),
      _value(context, s.statsEvilWins, _number(context, data.evilWins)),
      _value(context, s.statsWinRate,
        _decimal(context, data.goodWinRate) + '% (' + s.goodTeam + ')'),
      _value(context, s.statsAvgDuration,
        _minutes(data.averageDurationMinutes, s)),
      _value(context, s.statsAvgPlayers,
        _decimal(context, data.averagePlayers)),
      _value(context, s.statsScriptRoleCount,
        _number(context, script.roleCount)),
      if (data.demoGames > 0)
        _value(context, s.statsDemoGames, _number(context, data.demoGames)),
    ]);
  }

  Widget _scriptTile(BuildContext context, StatisticsScript script) {
    final s = AppLocalizations.of(context)!;
    final data = script.totals;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GrimoirePressablePanel(
        onTap: () => _scriptDetails(context, script),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(script.isCustom ? Icons.auto_awesome_outlined
                  : Icons.menu_book_outlined,
                color: GrimoireColors.antiqueGold),
              const SizedBox(width: 10),
              Expanded(child: Text(script.name, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right,
                color: GrimoireColors.secondaryText),
            ]),
            const SizedBox(height: 8),
            Text((script.isCustom ? s.statsCustom : s.statsStandard) +
              ' · ' + s.statsGames + ': ' + _number(context, data.games),
              style: const TextStyle(
                color: GrimoireColors.secondaryText, fontSize: 12)),
            const SizedBox(height: 10),
            ClipRRect(borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                minHeight: 7, value: data.games == 0
                  ? 0 : data.goodWins / data.games,
                backgroundColor: _evil, color: _good)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(s.goodTeam + ': ' +
                  _decimal(context, data.goodWinRate) + '%',
                  style: const TextStyle(color: _good, fontSize: 12))),
                Flexible(child: Text(s.statsAvgDuration + ': ' +
                  _minutes(data.averageDurationMinutes, s),
                  style: const TextStyle(
                    color: GrimoireColors.secondaryText, fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scriptsTab(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return FutureBuilder<List<StatisticsScript>>(
      future: _scripts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return _empty(context, s.statsError, error: true);
        final values = snapshot.data ?? [];
        if (values.isEmpty) return _empty(context, s.statsEmptyScripts);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GrimoireSectionHeading(title: s.statsCompareScripts,
              icon: Icons.auto_stories_outlined),
            const SizedBox(height: 12),
            for (final script in values) _scriptTile(context, script),
            Text(s.statsTop50, textAlign: TextAlign.center,
              style: const TextStyle(
                color: GrimoireColors.secondaryText, fontSize: 12)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tabs = [
      (s.statsOverview, Icons.dashboard_outlined),
      (s.statsRoles, Icons.people_alt_outlined),
      (s.statsScripts, Icons.auto_stories_outlined),
      (s.statsHistory, Icons.timeline_outlined),
    ];
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(s.statistics), backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              key: const ValueKey('stats-refresh'),
              tooltip: s.statsRefresh,
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(children: [
          const Positioned.fill(child: GrimoireBackgroundVeil()),
          Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey('stats-tab-$i'),
                      avatar: Icon(tabs[i].$2, size: 16,
                        color: i == _tab ? GrimoireColors.background
                            : GrimoireColors.antiqueGold),
                      label: Text(tabs[i].$1),
                      selected: _tab == i,
                      selectedColor: GrimoireColors.antiqueGold,
                      backgroundColor: GrimoireColors.surface,
                      labelStyle: TextStyle(fontSize: 12,
                        color: _tab == i ? GrimoireColors.background
                            : GrimoireColors.ivory),
                      side: BorderSide(color: GrimoireColors.antiqueGold
                        .withValues(alpha: 0.35)),
                      onSelected: (_) => _selectTab(i),
                    ),
                  ),
              ]),
            ),
            Expanded(child: ListView(
              key: const ValueKey('statisticsContent'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_tab == 0) _globalTab(context, history: false)
                else if (_tab == 1) _rolesTab(context)
                else if (_tab == 2) _scriptsTab(context)
                else _globalTab(context, history: true),
              ],
            )),
          ]),
        ]),
      ),
    );
  }
}
