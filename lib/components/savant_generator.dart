import 'dart:convert';
import 'dart:math';

import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SavantGenerator extends StatefulWidget {
  const SavantGenerator({super.key});

  @override
  State<SavantGenerator> createState() => _SavantGeneratorState();
}

class _SavantGeneratorState extends State<SavantGenerator> {
  final Random _random = Random();

  String _language = 'en';
  String? _statement;
  String? _loadError;
  List<String> _templates = const [];
  int? _previousTemplateIndex;
  int _loadRequest = 0;
  bool _initialized = false;
  bool _isLoading = true;

  String get _unavailableMessage => _language == 'de'
      ? 'Keine Savant-Aussage verfügbar.'
      : 'No Savant statement available.';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;
    _language = Localizations.localeOf(context).languageCode == 'de'
        ? 'de'
        : 'en';
    _loadStatements();
  }

  Future<void> _loadStatements() async {
    final language = _language;
    final request = ++_loadRequest;
    final bundle = DefaultAssetBundle.of(context);
    final path = 'assets/savant/$language.json';

    try {
      final source = await bundle.loadString(path);
      final decoded = jsonDecode(source);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        throw const FormatException('Expected a JSON array of strings.');
      }
      final templates = decoded
          .cast<String>()
          .map((statement) => statement.trim())
          .where((statement) => statement.isNotEmpty)
          .toList();

      if (!mounted || request != _loadRequest) return;
      final statement = _createRandomStatement(templates);
      setState(() {
        _templates = templates;
        _statement = statement;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Failed to load Savant statements from $path: $error');
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _templates = const [];
        _statement = null;
        _loadError = _language == 'de'
            ? 'Die Savant-Aussagen konnten nicht geladen werden.'
            : 'Could not load Savant statements.';
        _isLoading = false;
      });
    }
  }

  void _selectLanguage(String language) {
    if (language == _language) return;

    setState(() {
      _language = language;
      _templates = const [];
      _statement = null;
      _loadError = null;
      _previousTemplateIndex = null;
      _isLoading = true;
    });
    _loadStatements();
  }

  void _generateNewStatement() {
    if (_isLoading || _statement == null) return;
    setState(() {
      _statement = _createRandomStatement(_templates);
    });
  }

  String? _createRandomStatement(List<String> templates) {
    if (templates.isEmpty) return null;

    final characterService = context.read<CharacterService>();
    final gameStateService = context.read<GameStateService>();
    final scriptService = context.read<ScriptService>();
    final scriptCharacters =
        scriptService.resolveCharacters(characterService.allCharacters);

    final characters = scriptCharacters.where((character) {
      return character.fraction == Fraction.townsfolk ||
          character.fraction == Fraction.outsider ||
          character.fraction == Fraction.demon ||
          character.fraction == Fraction.minion;
    }).toList();
    final demons = scriptCharacters
        .where((character) => character.fraction == Fraction.demon)
        .toList();
    final minions = scriptCharacters
        .where((character) => character.fraction == Fraction.minion)
        .toList();
    final players = gameStateService.playerNames
        .where((name) => name.trim().isNotEmpty)
        .toList();

    // Ignore templates whose required placeholders cannot currently be filled.
    // [Number] and [Role Type] do not require any game data.
    final eligibleIndices = <int>[
      for (var index = 0; index < templates.length; index++)
        if (_canFillPlaceholders(
          templates[index],
          hasCharacters: characters.isNotEmpty,
          hasDemons: demons.isNotEmpty,
          hasMinions: minions.isNotEmpty,
          hasPlayers: players.isNotEmpty,
        ))
          index,
    ];
    if (eligibleIndices.isEmpty) return null;

    // Only avoid repeats among usable templates. If only one remains, reuse it.
    final choices = eligibleIndices.length > 1
        ? eligibleIndices
            .where((index) => index != _previousTemplateIndex)
            .toList()
        : eligibleIndices;
    final index = choices[_random.nextInt(choices.length)];
    _previousTemplateIndex = index;

    String randomCharacter(List<Character> choices, String placeholder) {
      if (choices.isEmpty) return placeholder;
      return choices[_random.nextInt(choices.length)].name;
    }

    String randomPlayer() => players[_random.nextInt(players.length)];

    String randomRoleType() {
      final types = _language == 'de'
          ? ['Bürger', 'Außenseiter', 'Dämon', 'Scherge']
          : ['Townsfolk', 'Outsider', 'Demon', 'Minion'];
      return types[_random.nextInt(types.length)];
    }

    String randomCharacterOrRoleType() {
      if (characters.isNotEmpty && _random.nextBool()) {
        return randomCharacter(characters, '[Character/Role Type]');
      }
      return randomRoleType();
    }

    var result = templates[index];
    result = result.replaceAllMapped(
      RegExp(r'\[Character/Role Type\]'),
      (_) => randomCharacterOrRoleType(),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[(?:Character|character)\]'),
      (match) => randomCharacter(characters, match.group(0)!),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Role Type\]'),
      (_) => randomRoleType(),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Demon\]'),
      (_) => randomCharacter(demons, '[Demon]'),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Minion\]'),
      (_) => randomCharacter(minions, '[Minion]'),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Player\]'),
      (_) => randomPlayer(),
    );
    result = result.replaceAllMapped(
      RegExp(r'\[Number\]'),
      (_) => (_random.nextInt(3) + 1).toString(),
    );
    return result;
  }

  bool _canFillPlaceholders(
    String template, {
    required bool hasCharacters,
    required bool hasDemons,
    required bool hasMinions,
    required bool hasPlayers,
  }) {
    for (final match in RegExp(r'\[[^\]]+\]').allMatches(template)) {
      switch (match.group(0)) {
        case '[Character]':
        case '[character]':
          if (!hasCharacters) return false;
          break;
        case '[Demon]':
          if (!hasDemons) return false;
          break;
        case '[Minion]':
          if (!hasMinions) return false;
          break;
        case '[Player]':
          if (!hasPlayers) return false;
          break;
        case '[Number]':
        case '[Role Type]':
        case '[Character/Role Type]':
          // Numbers and role types can always be generated.
          break;
        default:
          // Unknown placeholders should never appear unresolved in the popup.
          return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isGerman = _language == 'de';

    return Dialog(
      backgroundColor: const Color(0xFF282C34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Savant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isGerman ? 'Schließen' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'de', label: Text('DE')),
                  ButtonSegment(value: 'en', label: Text('EN')),
                ],
                selected: {_language},
                onSelectionChanged: (selection) {
                  _selectLanguage(selection.first);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : SingleChildScrollView(
                          child: Text(
                            _loadError ?? _statement ?? _unavailableMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _loadError == null
                                  ? Colors.white
                                  : Colors.orangeAccent,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading || _statement == null
                      ? null
                      : _generateNewStatement,
                  icon: const Icon(Icons.shuffle),
                  label: Text(isGerman ? 'Neue Aussage' : 'New statement'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF57456B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
