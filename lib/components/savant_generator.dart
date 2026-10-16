import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/chronicle_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A single placeholder occurrence, including repeated placeholders of the
/// same type. Keep these independent instead of replacing strings in bulk.
class SavantSlot {
  final String type;
  final String value;
  final String label;

  const SavantSlot(this.type, this.value, this.label);

  SavantSlot withValue(String value, String label) =>
      SavantSlot(type, value, label);

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'label': label,
      };

  factory SavantSlot.fromJson(Map<String, dynamic> json) => SavantSlot(
        json['type'] as String? ?? '',
        json['value'] as String? ?? '',
        json['label'] as String? ?? '',
      );
}

class SavantStatement {
  final String template;
  final String language;
  final List<SavantSlot> slots;

  const SavantStatement(this.template, this.language, this.slots);

  static final tokenPattern = RegExp(r'\[([^\]]+)\]');

  String get rendered {
    var slotIndex = 0;
    return template.replaceAllMapped(tokenPattern, (match) {
      if (slotIndex >= slots.length) return match.group(0)!;
      return slots[slotIndex++].label;
    });
  }

  SavantStatement replaceSlot(int index, SavantSlot slot) {
    final replacement = [...slots];
    replacement[index] = slot;
    return SavantStatement(template, language, replacement);
  }

  Map<String, dynamic> toJson() => {
        'template': template,
        'language': language,
        'rendered': rendered,
        'slots': slots.map((slot) => slot.toJson()).toList(),
      };

  factory SavantStatement.fromJson(Map<String, dynamic> json) {
    final raw = json['slots'];
    return SavantStatement(
      json['template'] as String? ?? json['rendered'] as String? ?? '',
      json['language'] as String? ?? 'en',
      raw is List
          ? raw.whereType<Map>().map((value) =>
              SavantSlot.fromJson(Map<String, dynamic>.from(value))).toList()
          : [],
    );
  }
}

class SavantGenerator extends StatefulWidget {
  const SavantGenerator({super.key});

  @override
  State<SavantGenerator> createState() => _SavantGeneratorState();
}

class _SavantGeneratorState extends State<SavantGenerator> {
  static const background = Color(0xFF21192F);
  static const gold = Color(0xFFD4AF67);
  final _random = Random();
  String _language = 'en';
  List<String> _templates = [];
  SavantStatement? _current;
  String? _error;
  bool _loading = true;
  bool _initialized = false;
  int _requestId = 0;
  int? _previousIndex;

  bool get _german => _language == 'de';
  String _translate(String de, String en) => _german ? de : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _language = Localizations.localeOf(context).languageCode == 'de'
        ? 'de'
        : 'en';
    _load();
  }

  List<Character> get _characters {
    final catalog = context.read<CharacterService>();
    final script = context.read<ScriptService>();
    return script.resolveCharacters(catalog.allCharacters).where((item) =>
        item.fraction == Fraction.townsfolk ||
        item.fraction == Fraction.outsider ||
        item.fraction == Fraction.demon ||
        item.fraction == Fraction.minion).toList();
  }

  List<String> get _players => context.read<GameStateService>().playerNames
      .where((name) => name.trim().isNotEmpty).toList();

  List<_Choice> _choices(String type) {
    if (type == 'Number') {
      return [for (var n = 0; n <= 20; n++) _Choice('$n', '$n')];
    }
    if (type == 'Player') {
      return _players.map((name) => _Choice(name, name)).toList();
    }
    const typeNames = ['townsfolk', 'outsider', 'minion', 'demon'];
    if (type == 'Role Type') {
      final names = _german
          ? ['Bürger', 'Außenseiter', 'Scherge', 'Dämon']
          : ['Townsfolk', 'Outsider', 'Minion', 'Demon'];
      return [
        for (var i = 0; i < typeNames.length; i++)
          _Choice(typeNames[i], names[i]),
      ];
    }
    var roles = _characters;
    if (type == 'Demon') {
      roles = roles.where((item) => item.fraction == Fraction.demon).toList();
    } else if (type == 'Minion') {
      roles = roles.where((item) => item.fraction == Fraction.minion).toList();
    }
    final choices = <_Choice>[
      for (final role in roles) _Choice(role.roleId, role.name),
    ];
    if (type == 'Character/Role Type') {
      choices.addAll(_choices('Role Type'));
    }
    return choices;
  }

  bool _canFill(String template) {
    const known = {
      'Number', 'Player', 'Character', 'character', 'Demon',
      'Minion', 'Role Type', 'Character/Role Type',
    };
    for (final match in SavantStatement.tokenPattern.allMatches(template)) {
      final name = match.group(1)!;
      if (!known.contains(name) || _choices(name).isEmpty) return false;
    }
    return true;
  }

  SavantStatement? _generate() {
    final eligible = <int>[
      for (var i = 0; i < _templates.length; i++)
        if (_canFill(_templates[i])) i,
    ];
    if (eligible.isEmpty) return null;
    final selection = eligible.length > 1
        ? eligible.where((index) => index != _previousIndex).toList()
        : eligible;
    final index = selection[_random.nextInt(selection.length)];
    _previousIndex = index;
    final template = _templates[index];
    final slots = <SavantSlot>[];
    for (final match in SavantStatement.tokenPattern.allMatches(template)) {
      final type = match.group(1)!;
      final choices = _choices(type);
      final choice = choices[_random.nextInt(choices.length)];
      slots.add(SavantSlot(type, choice.value, choice.label));
    }
    return SavantStatement(template, _language, slots);
  }

  Future<void> _load() async {
    final request = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await DefaultAssetBundle.of(context)
          .loadString('assets/savant/$_language.json');
      final parsed = jsonDecode(raw);
      if (parsed is! List || parsed.any((item) => item is! String)) {
        throw const FormatException('Expected an array of statements');
      }
      if (!mounted || request != _requestId) return;
      _templates = parsed.cast<String>()
          .map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
      setState(() {
        _current = _generate();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _error = _translate('Aussagen konnten nicht geladen werden.',
            'Could not load statements.');
        _loading = false;
        _current = null;
      });
    }
  }

  Future<void> _chooseSlot(SavantStatement statement, int index,
      {String? eventId}) async {
    if (index >= statement.slots.length) return;
    final slot = statement.slots[index];
    final choices = _choices(slot.type);
    final selected = await showModalBottomSheet<_Choice>(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _SlotPicker(
        title: slot.type,
        choices: choices,
        initial: slot.value,
        allowNumber: slot.type == 'Number',
      ),
    );
    if (selected == null || !mounted) return;
    final changed = statement.replaceSlot(index,
        slot.withValue(selected.value, selected.label));
    if (eventId == null) {
      setState(() => _current = changed);
    } else {
      await _save(changed, eventId: eventId);
    }
  }

  ChronicleCharacterSnapshot _actor() {
    final players = context.read<CharacterService>().gameCharacters;
    final savant = players.where((role) => role.roleId == 'savant').firstOrNull;
    if (savant != null) {
      return ChronicleCharacterSnapshot.fromCharacter(savant);
    }
    return const ChronicleCharacterSnapshot(
      characterId: 'savant',
      roleId: 'savant',
      roleName: 'Savant',
      playerName: '',
      image: 'Icon_savant',
    );
  }

  Future<void> _save(SavantStatement statement, {String? eventId}) async {
    final game = context.read<GameStateService>();
    final chronicle = context.read<ChronicleService>();
    if (game.nightCount < 1 || chronicle.activeChronicle == null) return;
    await chronicle.upsertSavantStatement(
      eventId: eventId,
      round: game.nightCount,
      actor: _actor(),
      statement: statement.toJson(),
    );
  }

  Widget _statementText(SavantStatement statement, {String? eventId}) {
    final spans = <InlineSpan>[];
    var start = 0;
    var slotIndex = 0;
    for (final match in SavantStatement.tokenPattern.allMatches(statement.template)) {
      if (match.start > start) {
        spans.add(TextSpan(text: statement.template.substring(start, match.start)));
      }
      final index = slotIndex++;
      final slot = index < statement.slots.length
          ? statement.slots[index]
          : SavantSlot('', '', match.group(0)!);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _chooseSlot(statement, index, eventId: eventId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gold.withValues(alpha: 0.5)),
                color: const Color(0xFF4B385D),
              ),
              child: Text(slot.label, style: const TextStyle(
                color: gold, fontWeight: FontWeight.w600, fontSize: 15,
              )),
            ),
          ),
        ),
      ));
      start = match.end;
    }
    if (start < statement.template.length) {
      spans.add(TextSpan(text: statement.template.substring(start)));
    }
    return Text.rich(TextSpan(children: spans), style: const TextStyle(
      color: Colors.white, fontSize: 16, height: 1.55,
    ));
  }

  Widget _savedCard(ChronicleEvent event) {
    final raw = event.details['statement'];
    if (raw is! Map) return const SizedBox.shrink();
    final statement = SavantStatement.fromJson(Map<String, dynamic>.from(raw));
    return Card(
      color: background.withValues(alpha: 0.92),
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: true,
            activeColor: gold,
            checkColor: Colors.black,
            onChanged: (_) =>
                context.read<ChronicleService>().removeSavantStatement(event.id),
          ),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: _statementText(statement, eventId: event.id),
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameStateService>();
    final chronicle = context.watch<ChronicleService>();
    final saved = chronicle.activeChronicle?.events.where((event) =>
        event.type == ChronicleEventType.savantStatement &&
        event.round == game.nightCount).toList() ?? <ChronicleEvent>[];
    return AppBackground(
      type: AppBackgroundType.ui,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Savant'),
          backgroundColor: background.withValues(alpha: 0.78),
          leading: IconButton(
            tooltip: _translate('Zurück', 'Back'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
              segments: const [
                ButtonSegment(value: 'de', label: Text('DE')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {_language},
              onSelectionChanged: (set) {
                _language = set.first;
                _previousIndex = null;
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(_translate('Gespeicherte Aussagen', 'Saved statements') +
                    ' (${saved.length})',
                style: const TextStyle(
                    fontSize: 18, color: gold, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (saved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_translate('Noch keine Aussagen ausgewählt.',
                    'No statements selected yet.'),
                    style: const TextStyle(color: Colors.white70)),
              ),
            for (final event in saved) _savedCard(event),
            const SizedBox(height: 24),
            const Divider(color: gold),
            const SizedBox(height: 14),
            Text(_translate('Neue Aussage', 'New statement'),
                style: const TextStyle(
                    fontSize: 18, color: gold, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              color: background.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Text(_error!, style: const TextStyle(color: Colors.orangeAccent))
                        : _current == null
                            ? Text(_translate('Keine passende Aussage verfügbar.',
                                'No eligible statement available.'))
                            : InkWell(
                                onTap: () => _save(_current!),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: _statementText(_current!),
                                ),
                              ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _current == null ? null : () {
                setState(() => _current = _generate());
              },
              icon: const Icon(Icons.shuffle),
              label: Text(_translate('Neue Aussage generieren',
                  'Generate another statement')),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF57456B),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 8),
            Text(_translate(
              'Aussage antippen zum Speichern. Goldene Werte antippen zum Ändern.',
              'Tap a statement to save. Tap gold values to edit.',
            ), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _Choice {
  final String value;
  final String label;
  const _Choice(this.value, this.label);
}

class _SlotPicker extends StatefulWidget {
  final String title;
  final List<_Choice> choices;
  final String initial;
  final bool allowNumber;
  const _SlotPicker({
    required this.title,
    required this.choices,
    required this.initial,
    required this.allowNumber,
  });

  @override
  State<_SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<_SlotPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.choices.where((choice) =>
        choice.label.toLowerCase().contains(query.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.64,
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(widget.title,
                style: const TextStyle(fontSize: 20, color: Colors.white))),
            IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          TextField(
            autofocus: false,
            keyboardType: widget.allowNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.allowNumber ? '0–9999' : 'Search / Suchen',
            ),
            onChanged: (text) => setState(() => query = text),
            onSubmitted: (text) {
              if (!widget.allowNumber) return;
              final n = int.tryParse(text);
              if (n != null && n >= 0) {
                Navigator.pop(context, _Choice('$n', '$n'));
              }
            },
          ),
          if (widget.allowNumber && int.tryParse(query) != null &&
              int.parse(query) >= 0)
            ListTile(
              title: Text(query),
              trailing: const Icon(Icons.check),
              onTap: () => Navigator.pop(context, _Choice(query, query)),
            ),
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final choice = filtered[index];
              return ListTile(
                selected: choice.value == widget.initial,
                title: Text(choice.label),
                onTap: () => Navigator.pop(context, choice),
              );
            },
          )),
        ]),
      ),
    );
  }
}
