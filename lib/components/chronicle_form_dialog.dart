import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/models/chronicle_schema.dart';
import 'package:blood_on_the_clocktower/screens/player_selection_screen.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';

class ChronicleFormResult {
  final Map<String, dynamic> values;
  final bool delete;

  const ChronicleFormResult(this.values, {this.delete = false});
}

class ChronicleFormDialog extends StatefulWidget {
  final ChronicleInputDefinition definition;
  final Map<String, dynamic> initialValues;
  final List<ChronicleCharacterSnapshot> players;
  final List<ChronicleCharacterSnapshot> characters;
  final bool canDelete;

  const ChronicleFormDialog({
    super.key,
    required this.definition,
    required this.initialValues,
    required this.players,
    required this.characters,
    this.canDelete = false,
  });

  @override
  State<ChronicleFormDialog> createState() => _ChronicleFormDialogState();
}

class _ChronicleFormDialogState extends State<ChronicleFormDialog> {
  late final Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _invalidNumbers = {};

  @override
  void initState() {
    super.initState();
    _values = _deepCopy(widget.initialValues);
    for (final field in _leafFields(widget.definition)) {
      if (field.type == ChronicleInputType.number ||
          field.type == ChronicleInputType.text) {
        _controllers[field.id] = TextEditingController(
          text: _values[field.id]?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF332644),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.definition.label),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildDefinition(widget.definition),
          ),
        ),
      ),
      actions: [
        if (widget.canDelete)
          TextButton.icon(
            onPressed: () => Navigator.pop(
              context,
              const ChronicleFormResult({}, delete: true),
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(localized.chronicleRemoveEntry),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localized.cancel),
        ),
        FilledButton(
          onPressed: _invalidNumbers.isEmpty
              ? () => Navigator.pop(
                    context,
                    ChronicleFormResult(_deepCopy(_values)),
                  )
              : null,
          child: Text(localized.save),
        ),
      ],
    );
  }

  List<Widget> _buildDefinition(ChronicleInputDefinition definition) {
    if (definition.type == ChronicleInputType.form) {
      return [
        for (final field in definition.fields) ...[
          ..._buildDefinition(field),
          const SizedBox(height: 16),
        ],
      ];
    }
    return [
      Text(
        definition.label,
        style: const TextStyle(
          color: Color(0xFFE5D6B4),
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 7),
      _buildField(definition),
    ];
  }

  Widget _buildField(ChronicleInputDefinition field) => switch (field.type) {
        ChronicleInputType.number => _numberField(field),
        ChronicleInputType.yesNo => _yesNoField(field),
        ChronicleInputType.player => _snapshotField(field, players: true),
        ChronicleInputType.players => _snapshotField(field, players: true),
        ChronicleInputType.character => _snapshotField(field, players: false),
        ChronicleInputType.characters => _snapshotField(field, players: false),
        ChronicleInputType.choice => _choiceField(field),
        ChronicleInputType.text => _textField(field),
        ChronicleInputType.form => const SizedBox.shrink(),
      };

  Widget _numberField(ChronicleInputDefinition field) {
    final range = switch ((field.min, field.max)) {
      (final int min, final int max) => '$min–$max',
      (final int min, null) => '≥ $min',
      (null, final int max) => '≤ $max',
      _ => null,
    };
    return TextField(
      key: ValueKey('chronicle-field-${field.id}'),
      controller: _controllers[field.id],
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(
        hintText: range,
        errorText: _invalidNumbers.contains(field.id)
            ? AppLocalizations.of(context)!.chronicleInvalidNumber
            : null,
      ),
      onChanged: (raw) {
        final value = int.tryParse(raw.trim());
        final valid = raw.trim().isEmpty ||
            (value != null &&
                (field.min == null || value >= field.min!) &&
                (field.max == null || value <= field.max!));
        setState(() {
          if (valid) {
            _invalidNumbers.remove(field.id);
          } else {
            _invalidNumbers.add(field.id);
          }
          if (raw.trim().isEmpty) {
            _values.remove(field.id);
          } else if (valid) {
            _values[field.id] = value;
          }
        });
      },
    );
  }

  Widget _yesNoField(ChronicleInputDefinition field) {
    final localized = AppLocalizations.of(context)!;
    final value = _values[field.id] as bool?;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          key: ValueKey('chronicle-${field.id}-yes'),
          label: Text(localized.chronicleAnswerYes),
          selected: value == true,
          onSelected: (_) => setState(() => _values[field.id] = true),
        ),
        ChoiceChip(
          key: ValueKey('chronicle-${field.id}-no'),
          label: Text(localized.chronicleAnswerNo),
          selected: value == false,
          onSelected: (_) => setState(() => _values[field.id] = false),
        ),
        if (value != null)
          IconButton(
            tooltip: localized.chronicleClearValue,
            onPressed: () => setState(() => _values.remove(field.id)),
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }

  Widget _choiceField(ChronicleInputDefinition field) {
    final value = _values[field.id] as String?;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final option in field.options)
          ChoiceChip(
            label: Text(option.label),
            selected: value == option.value,
            onSelected: (_) => setState(() => _values[field.id] = option.value),
          ),
        if (value != null)
          IconButton(
            tooltip: AppLocalizations.of(context)!.chronicleClearValue,
            onPressed: () => setState(() => _values.remove(field.id)),
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }

  Widget _textField(ChronicleInputDefinition field) => TextField(
        key: ValueKey('chronicle-field-${field.id}'),
        controller: _controllers[field.id],
        minLines: 2,
        maxLines: 5,
        onChanged: (value) => setState(() {
          if (value.trim().isEmpty) {
            _values.remove(field.id);
          } else {
            _values[field.id] = value;
          }
        }),
      );

  Widget _snapshotField(
    ChronicleInputDefinition field, {
    required bool players,
  }) {
    final choices = players ? widget.players : widget.characters;
    final multiple = field.type == ChronicleInputType.players ||
        field.type == ChronicleInputType.characters;
    final selected = _selectedSnapshots(field, multiple: multiple);
    final localized = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final snapshot in selected)
                InputChip(
                  label: Text(_snapshotName(snapshot, players: players)),
                  onDeleted: () => setState(() {
                    selected.removeWhere(
                      (item) => item.characterId == snapshot.characterId,
                    );
                    _storeSnapshots(field, selected, multiple: multiple);
                  }),
                ),
            ],
          ),
        OutlinedButton.icon(
          key: ValueKey('chronicle-select-${field.id}'),
          onPressed: () async {
            final result = players
                ? await _selectPlayers(
                    context,
                    field: field,
                    choices: choices,
                    initial: selected,
                  )
                : await _selectSnapshots(
                    context,
                    title: field.label,
                    choices: choices,
                    initial: selected,
                    multiple: multiple,
                    maximum: field.effectiveMaxCount,
                    players: false,
                  );
            if (result == null) return;
            setState(() => _storeSnapshots(field, result, multiple: multiple));
          },
          icon: Icon(players ? Icons.people_outline : Icons.shield_outlined),
          label: Text(localized.chronicleSelect),
        ),
        if (multiple && (field.minCount != null || field.maxCount != null))
          Text(
            _countHint(field),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
      ],
    );
  }

  List<ChronicleCharacterSnapshot> _selectedSnapshots(
    ChronicleInputDefinition field, {
    required bool multiple,
  }) {
    final raw = _values[field.id];
    if (multiple) {
      return (raw is List ? raw : const [])
          .whereType<Map>()
          .map((item) => ChronicleCharacterSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    }
    return raw is Map
        ? [
            ChronicleCharacterSnapshot.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          ]
        : [];
  }

  void _storeSnapshots(
    ChronicleInputDefinition field,
    List<ChronicleCharacterSnapshot> snapshots, {
    required bool multiple,
  }) {
    if (snapshots.isEmpty) {
      _values.remove(field.id);
    } else if (multiple) {
      _values[field.id] = snapshots.map((item) => item.toJson()).toList();
    } else {
      _values[field.id] = snapshots.first.toJson();
    }
  }

  Future<List<ChronicleCharacterSnapshot>?> _selectSnapshots(
    BuildContext context, {
    required String title,
    required List<ChronicleCharacterSnapshot> choices,
    required List<ChronicleCharacterSnapshot> initial,
    required bool multiple,
    required int? maximum,
    required bool players,
  }) {
    final selectedIds = initial.map((item) => item.characterId).toSet();
    var query = '';
    return showDialog<List<ChronicleCharacterSnapshot>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = choices.where((item) {
            final name = _snapshotName(item, players: players).toLowerCase();
            return name.contains(query.toLowerCase());
          }).toList();
          return AlertDialog(
            backgroundColor: const Color(0xFF332644),
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: AppLocalizations.of(context)!.chronicleSearch,
                    ),
                    onChanged: (value) => setDialogState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final selected = selectedIds.contains(item.characterId);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(_snapshotName(item, players: players)),
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xFFB5987D),
                            backgroundImage: item.image.isEmpty
                                ? null
                                : AssetImage(roleImageAssetPath(item.image)),
                          ),
                          onChanged: (_) => setDialogState(() {
                            if (selected) {
                              selectedIds.remove(item.characterId);
                            } else {
                              if (!multiple) selectedIds.clear();
                              if (maximum == null ||
                                  selectedIds.length < maximum) {
                                selectedIds.add(item.characterId);
                              }
                            }
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  choices
                      .where((item) => selectedIds.contains(item.characterId))
                      .toList(growable: false),
                ),
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<ChronicleCharacterSnapshot>?> _selectPlayers(
    BuildContext context, {
    required ChronicleInputDefinition field,
    required List<ChronicleCharacterSnapshot> choices,
    required List<ChronicleCharacterSnapshot> initial,
  }) =>
      Navigator.of(context).push<List<ChronicleCharacterSnapshot>>(
        MaterialPageRoute(
          builder: (_) => PlayerSelectionScreen(
            title: field.label,
            choices: choices,
            initial: initial,
            minCount: field.effectiveMinCount,
            maxCount: field.effectiveMaxCount,
          ),
        ),
      );

  String _snapshotName(
    ChronicleCharacterSnapshot snapshot, {
    required bool players,
  }) {
    if (players && snapshot.playerName.isNotEmpty) {
      return '${snapshot.playerName} · ${snapshot.roleName}';
    }
    return snapshot.roleName.isNotEmpty ? snapshot.roleName : snapshot.roleId;
  }

  String _countHint(ChronicleInputDefinition field) {
    if (field.minCount != null && field.minCount == field.maxCount) {
      return AppLocalizations.of(context)!.chronicleExactCount(field.minCount!);
    }
    return AppLocalizations.of(context)!.chronicleCountRange(
      field.minCount ?? 0,
      field.maxCount?.toString() ?? '∞',
    );
  }

  List<ChronicleInputDefinition> _leafFields(
    ChronicleInputDefinition definition,
  ) =>
      definition.type == ChronicleInputType.form
          ? definition.fields.expand(_leafFields).toList(growable: false)
          : [definition];

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) =>
      source.map((key, value) => MapEntry(key, _copyValue(value)));

  dynamic _copyValue(dynamic value) {
    if (value is Map) {
      return value
          .map((key, item) => MapEntry(key.toString(), _copyValue(item)));
    }
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }
}
