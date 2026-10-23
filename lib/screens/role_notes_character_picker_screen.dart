import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/select_character_component.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Uses the same grouped character grid as game setup. Changes remain local
/// until Assign is pressed, so backing out preserves the player's notes.
class RoleNotesCharacterPickerScreen extends StatefulWidget {
  final String playerName;

  const RoleNotesCharacterPickerScreen({
    super.key,
    required this.playerName,
  });

  @override
  State<RoleNotesCharacterPickerScreen> createState() =>
      _RoleNotesCharacterPickerScreenState();
}

class _RoleNotesCharacterPickerScreenState
    extends State<RoleNotesCharacterPickerScreen> {
  late final List<String> _selectedRoleImages;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedRoleImages = context
        .read<RoleNotesService>()
        .roleImagesFor(widget.playerName)
        .toList();
  }

  void _toggleCharacter(Character character) {
    if (_selectedRoleImages.contains(character.image)) {
      setState(() => _selectedRoleImages.remove(character.image));
    } else if (_selectedRoleImages.length < 4) {
      setState(() => _selectedRoleImages.add(character.image));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.maxFourRoles)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final characters = context.watch<CharacterService>().allCharacters;
    final scriptService = context.watch<ScriptService>();
    // Match game setup's script order and fraction grouping.
    final availableRoles = scriptService
        .resolveCharacters(characters)
        .where((character) => character.fraction != Fraction.fabled)
        .toList();
    final filteredRoles = availableRoles.where((character) =>
        character.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '${strings.chooseRolesFor} ${widget.playerName}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_selectedRoleImages.length}/4',
                  key: const ValueKey('role-notes-selection-count'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildSelectedChips(characters),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                key: const ValueKey('role-notes-role-search'),
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: strings.searchRoles,
                  labelStyle: const TextStyle(color: Colors.white),
                  suffixIcon: const Icon(Icons.search, color: Colors.white),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: filteredRoles.isEmpty
                  ? Center(
                      child: Text(
                        strings.noRolesFound,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : SelectCharacterComponent(
                      charactersToChooseFrom: filteredRoles,
                      onConfirm: () {},
                      title: strings.roleNotes,
                      confirmButtonText: strings.assign,
                      needToConfirm: false,
                      showBackground: false,
                      travellersAreSelectable: true,
                      loricAreSelectable: true,
                      hideEmptySections: _query.isNotEmpty,
                      selectedCharacterImages: _selectedRoleImages.toSet(),
                      onCharacterSelectionChanged: _toggleCharacter,
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('role-notes-clear-selection'),
                  onPressed: () =>
                      setState(() => _selectedRoleImages.clear()),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(strings.clearRoles),
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('role-notes-cancel-selection'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(strings.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('role-notes-assign-selection'),
                  onPressed: () => Navigator.pop(
                    context,
                    List<String>.from(_selectedRoleImages),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(strings.assign),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChips(List<Character> characters) {
    final strings = AppLocalizations.of(context)!;
    if (_selectedRoleImages.isEmpty) {
      return Text(
        strings.noRoleNotesYet,
        style: const TextStyle(color: Colors.white70),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _selectedRoleImages.map((roleImage) {
        final character = characters
            .where((item) => item.image == roleImage)
            .firstOrNull;
        return Chip(
          backgroundColor: const Color(0xFF493131),
          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
          onDeleted: () =>
              setState(() => _selectedRoleImages.remove(roleImage)),
          avatar: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: AssetImage(roleImageAssetPath(roleImage)),
          ),
          label: Text(
            character?.name ?? roleImage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }
}
