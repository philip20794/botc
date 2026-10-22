import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/components/standard_role_distribution_indicator.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/enums/fraction.dart';
import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
import 'package:blood_on_the_clocktower/services/script_service.dart';
import 'package:blood_on_the_clocktower/services/settings_service.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:blood_on_the_clocktower/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class RoleNotesScreen extends StatefulWidget {
  const RoleNotesScreen({super.key});

  @override
  State<RoleNotesScreen> createState() => _RoleNotesScreenState();
}

class _RoleNotesScreenState extends State<RoleNotesScreen> {
  final GlobalKey _boardKey = GlobalKey();
  Size _lastBoardSize = Size.zero;
  double _lastPlayerTokenSize = 0;
  String? _draggingPlayerName;
  final Map<String, Offset> _dragPositions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final characterService =
          Provider.of<CharacterService>(context, listen: false);
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      if (characterService.allCharacters.isEmpty) {
        characterService.loadAllCharactersFromJson(languageService.locale);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizedStrings = AppLocalizations.of(context)!;
    final gameStateService = Provider.of<GameStateService>(context);
    final roleNotesService = Provider.of<RoleNotesService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final characterService = Provider.of<CharacterService>(context);
    final playerNames = List<String>.from(gameStateService.playerNames);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            localizedStrings.roleNotes,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _resetLayout(playerNames),
            ),
            if (roleNotesService.hasAnyRoleNotes())
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                onPressed: () => _confirmClearAllRoleNotes(context),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (playerNames.isEmpty)
              Center(
                child: Text(
                  localizedStrings.noPlayerYet,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            else
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.biggest;
                    // Use the same character and token sizing as Layout Settings.
                    final playerTokenSize = settingsService.characterKnobSize;
                    final roleBadgeScale = settingsService.tokenKnobSize /
                        ResponsiveLayoutDefaults.forViewport(
                          ResponsiveLayoutDefaults.referenceViewport,
                        ).tokenKnobSize;
                    final maxRoleTokenSize =
                        _roleBadgeSizeFor(1) * roleBadgeScale;
                    final nodeSize = playerTokenSize + maxRoleTokenSize * 1.95;
                    final nodePadding = (nodeSize - playerTokenSize) / 2;
                    _lastBoardSize = boardSize;
                    _lastPlayerTokenSize = playerTokenSize;

                    if (roleNotesService.needsPositionSync(
                      playerNames,
                      boardSize,
                      playerTokenSize,
                      layoutSettings: settingsService,
                    )) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        roleNotesService.ensureDefaultPositions(
                          playerNames,
                          boardSize,
                          playerTokenSize,
                          layoutSettings: settingsService,
                        );
                      });
                    }

                    final duplicateRoles =
                        roleNotesService.duplicateRoleImages();
                    final duplicateRoleImages = duplicateRoles.keys.toSet();
                    final roleNamesByImage = {
                      for (final character in characterService.allCharacters)
                        character.image: character.name
                    };
                    final positions = <String, Offset>{};
                    final playerRoles = <String, List<String>>{};
                    for (final playerName in playerNames) {
                      final position = roleNotesService.positionOf(playerName);
                      if (position != null) {
                        positions[playerName] =
                            _dragPositions[playerName] ?? position;
                      }
                      playerRoles[playerName] =
                          roleNotesService.roleImagesFor(playerName);
                    }

                    return SizedBox.expand(
                      child: Stack(
                        key: _boardKey,
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _RoleConnectionPainter(
                                    positions: positions,
                                    duplicateRoles: duplicateRoles,
                                    playerTokenSize: playerTokenSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          for (final playerName in playerNames)
                            if (positions[playerName] != null)
                              _buildDraggablePlayer(
                                context,
                                playerName,
                                positions[playerName]!,
                                playerRoles[playerName] ?? const [],
                                duplicateRoleImages,
                                roleNamesByImage,
                                boardSize,
                                nodeSize,
                                nodePadding,
                                playerTokenSize,
                                maxRoleTokenSize,
                                roleBadgeScale,
                              ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // Keep the count in the centre of the board, above the connection
            // lines. IgnorePointer allows dragging the players beneath it.
            if (playerNames.length >= 5)
              Positioned.fill(
                child: Center(
                  child: StandardRoleDistributionIndicator(
                    playerCount: playerNames.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggablePlayer(
    BuildContext context,
    String playerName,
    Offset position,
    List<String> selectedRoleImages,
    Set<String> duplicateRoleImages,
    Map<String, String> roleNamesByImage,
    Size boardSize,
    double nodeSize,
    double nodePadding,
    double playerTokenSize,
    double maxRoleTokenSize,
    double roleBadgeScale,
  ) {
    final roleNotesService =
        Provider.of<RoleNotesService>(context, listen: false);

    return Positioned(
      left: position.dx - nodePadding,
      top: position.dy - nodePadding,
      child: _buildPlayerNode(
        context,
        playerName,
        nodeSize,
        playerTokenSize,
        maxRoleTokenSize,
        roleBadgeScale,
        selectedRoleImages,
        duplicateRoleImages,
        roleNamesByImage,
        onDragStarted: () {
          setState(() {
            _draggingPlayerName = playerName;
            _dragPositions[playerName] = position;
          });
        },
        onDragUpdate: (details) {
          final currentPosition = _dragPositions[playerName] ??
              roleNotesService.positionOf(playerName) ??
              position;
          final nextPosition = roleNotesService.clampPlayerPosition(
            currentPosition + details.delta,
            boardSize,
            playerTokenSize,
          );
          if (_dragPositions[playerName] == nextPosition) {
            return;
          }
          setState(() {
            _dragPositions[playerName] = nextPosition;
          });
        },
        onDragFinished: () {
          final finalPosition = _dragPositions[playerName] ?? position;
          roleNotesService.setPlayerPosition(
            playerName,
            finalPosition,
            boardSize,
            playerTokenSize,
          );
          setState(() {
            _draggingPlayerName = null;
            _dragPositions.remove(playerName);
          });
        },
        isDragging: _draggingPlayerName == playerName,
      ),
    );
  }

  Widget _buildPlayerNode(
    BuildContext context,
    String playerName,
    double nodeSize,
    double playerTokenSize,
    double maxRoleTokenSize,
    double roleBadgeScale,
    List<String> selectedRoleImages,
    Set<String> duplicateRoleImages,
    Map<String, String> roleNamesByImage, {
    required VoidCallback onDragStarted,
    required GestureDragUpdateCallback onDragUpdate,
    required VoidCallback onDragFinished,
    bool isDragging = false,
  }) {
    final roleTokenSize =
        _roleBadgeSizeFor(selectedRoleImages.length) * roleBadgeScale;
    final center = nodeSize / 2;

    return RepaintBoundary(
      child: Opacity(
        opacity: isDragging ? 0.9 : 1,
        child: SizedBox(
          width: nodeSize,
          height: nodeSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: center - playerTokenSize / 2,
                top: center - playerTokenSize / 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showRolePicker(context, playerName),
                  onPanStart: (_) => onDragStarted(),
                  onPanUpdate: onDragUpdate,
                  onPanEnd: (_) => onDragFinished(),
                  onPanCancel: onDragFinished,
                  child: SizedBox(
                    width: playerTokenSize,
                    height: playerTokenSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: playerTokenSize,
                          height: playerTokenSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedRoleImages.isEmpty
                                  ? Colors.white.withOpacity(0.45)
                                  : Colors.white,
                              width: 3,
                            ),
                            image: const DecorationImage(
                              image: AssetImage(
                                  'assets/images/backgrounds/token.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _initialsFor(playerName),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: playerTokenSize * 0.28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: playerTokenSize * 0.05,
                          top: playerTokenSize * 0.75,
                          child: Container(
                            width: playerTokenSize * 0.9,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF493131).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AutoSizeText(
                              playerName,
                              textAlign: TextAlign.center,
                              minFontSize: 7,
                              maxFontSize: 12,
                              maxLines: 1,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        if (selectedRoleImages.isEmpty)
                          Positioned(
                            right: playerTokenSize * 0.02,
                            top: playerTokenSize * 0.02,
                            child: Container(
                              width: maxRoleTokenSize * 0.58,
                              height: maxRoleTokenSize * 0.58,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: GrimoireColors.deepViolet,
                              ),
                              child: Icon(
                                Icons.add,
                                color: GrimoireColors.ivory,
                                size: maxRoleTokenSize * 0.36,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < selectedRoleImages.length; i++)
                _buildRoleBadge(
                  context,
                  playerName,
                  selectedRoleImages[i],
                  roleNamesByImage[selectedRoleImages[i]] ??
                      selectedRoleImages[i],
                  i,
                  selectedRoleImages.length,
                  nodeSize,
                  playerTokenSize,
                  roleTokenSize,
                  duplicateRoleImages.contains(selectedRoleImages[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(
    BuildContext context,
    String playerName,
    String roleImage,
    String roleName,
    int index,
    int roleCount,
    double nodeSize,
    double playerTokenSize,
    double roleTokenSize,
    bool isSharedRole,
  ) {
    final roleNotesService =
        Provider.of<RoleNotesService>(context, listen: false);
    final center = nodeSize / 2;
    final badgeRadius = playerTokenSize * 0.58;
    final angle = -pi / 2 + 2 * pi * index / max(1, roleCount);
    final left = center + cos(angle) * badgeRadius - roleTokenSize / 2;
    final top = center + sin(angle) * badgeRadius - roleTokenSize / 2;
    final roleColor = _roleColor(roleImage);

    return Positioned(
      left: left,
      top: top,
      child: Tooltip(
        message: roleName,
        child: GestureDetector(
          onTap: () => roleNotesService.removeRoleFromPlayer(
            playerName,
            roleImage,
          ),
          child: Container(
            width: roleTokenSize,
            height: roleTokenSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF493131),
              border: Border.all(
                color: isSharedRole ? roleColor : Colors.white,
                width: isSharedRole ? 3 : 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(roleTokenSize * 0.06),
              child: Image.asset(
                roleImageAssetPath(roleImage),
                cacheWidth: _imageCacheWidth(context, roleTokenSize),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRolePicker(BuildContext context, String playerName) async {
    final localizedStrings = AppLocalizations.of(context)!;
    final roleNotesService =
        Provider.of<RoleNotesService>(context, listen: false);
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    final scriptService = Provider.of<ScriptService>(context, listen: false);
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    if (characterService.allCharacters.isEmpty) {
      await characterService.loadAllCharactersFromJson(languageService.locale);
      if (!context.mounted) {
        return;
      }
    }

    final availableRoles = _availableRoles(characterService, scriptService);
    final selectedRoleImages =
        roleNotesService.roleImagesFor(playerName).toList();
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredRoles = availableRoles.where((character) {
              return character.name.toLowerCase().contains(query.toLowerCase());
            }).toList();
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                child: FractionallySizedBox(
                  heightFactor: 0.92,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: GrimoireColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: AutoSizeText(
                                  '${localizedStrings.chooseRolesFor} $playerName',
                                  maxLines: 1,
                                  minFontSize: 14,
                                  maxFontSize: 20,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildSelectedRoleChips(
                            context,
                            selectedRoleImages,
                            (roleImage) {
                              setDialogState(() {
                                selectedRoleImages.remove(roleImage);
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: TextField(
                            cursorColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: localizedStrings.searchRoles,
                              labelStyle: const TextStyle(color: Colors.white),
                              suffixIcon:
                                  const Icon(Icons.search, color: Colors.white),
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                query = value;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: filteredRoles.isEmpty
                              ? Center(
                                  child: Text(
                                    localizedStrings.noRolesFound,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final crossAxisCount = max(
                                        2, min(4, constraints.maxWidth ~/ 88));
                                    final tileWidth =
                                        constraints.maxWidth / crossAxisCount;
                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 12),
                                      itemCount: filteredRoles.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio: 0.78,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                      ),
                                      itemBuilder: (context, index) {
                                        final character = filteredRoles[index];
                                        final isSelected = selectedRoleImages
                                            .contains(character.image);
                                        return _buildRolePickerTile(
                                          context,
                                          character,
                                          isSelected,
                                          tileWidth,
                                          () {
                                            setDialogState(() {
                                              if (isSelected) {
                                                selectedRoleImages
                                                    .remove(character.image);
                                              } else if (selectedRoleImages
                                                      .length <
                                                  4) {
                                                selectedRoleImages
                                                    .add(character.image);
                                              } else {
                                                ScaffoldMessenger.of(
                                                        this.context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        localizedStrings
                                                            .maxFourRoles),
                                                  ),
                                                );
                                              }
                                            });
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            border: const Border(
                              top: BorderSide(color: Colors.white24),
                            ),
                          ),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedRoleImages.clear();
                                  });
                                },
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                                label: Text(
                                  localizedStrings.clearRoles,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: Text(
                                  localizedStrings.cancel,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF493131),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  roleNotesService.setRolesForPlayer(
                                    playerName,
                                    selectedRoleImages,
                                  );
                                  Navigator.pop(sheetContext);
                                },
                                icon: const Icon(Icons.check),
                                label: Text(localizedStrings.assign),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedRoleChips(
    BuildContext context,
    List<String> selectedRoleImages,
    Function(String roleImage) onRemove,
  ) {
    final localizedStrings = AppLocalizations.of(context)!;
    final characterService = Provider.of<CharacterService>(context);

    if (selectedRoleImages.isEmpty) {
      return Text(
        localizedStrings.noRoleNotesYet,
        style: const TextStyle(color: Colors.white70),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: selectedRoleImages.map((roleImage) {
        final character =
            _characterByImage(characterService.allCharacters, roleImage);
        return Chip(
          backgroundColor: const Color(0xFF493131),
          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
          onDeleted: () => onRemove(roleImage),
          avatar: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: ResizeImage(
              AssetImage(roleImageAssetPath(roleImage)),
              width: _imageCacheWidth(context, 32),
            ),
          ),
          label: Text(
            character?.name ?? roleImage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRolePickerTile(
    BuildContext context,
    Character character,
    bool isSelected,
    double tileWidth,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? GrimoireColors.deepViolet.withValues(alpha: 0.95)
              : GrimoireColors.background.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? GrimoireColors.antiqueGold
                : GrimoireColors.antiqueGold.withValues(alpha: 0.22),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                roleImageAssetPath(character.image),
                cacheWidth: _imageCacheWidth(context, tileWidth),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 4),
            AutoSizeText(
              character.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              minFontSize: 7,
              maxFontSize: 11,
              style: const TextStyle(color: GrimoireColors.ivory),
            ),
          ],
        ),
      ),
    );
  }

  void _resetLayout(List<String> playerNames) {
    if (_lastBoardSize == Size.zero || _lastPlayerTokenSize <= 0) {
      return;
    }
    Provider.of<RoleNotesService>(context, listen: false).resetPositions(
      playerNames,
      _lastBoardSize,
      _lastPlayerTokenSize,
      layoutSettings: Provider.of<SettingsService>(context, listen: false),
    );
  }

  void _confirmClearAllRoleNotes(BuildContext context) {
    final localizedStrings = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            localizedStrings.clearAllRoleNotes,
            style: const TextStyle(color: GrimoireColors.ivory),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                localizedStrings.cancel,
                style: const TextStyle(color: GrimoireColors.ivory),
              ),
            ),
            TextButton(
              onPressed: () {
                Provider.of<RoleNotesService>(context, listen: false)
                    .clearAllRoleNotes();
                Navigator.pop(dialogContext);
              },
              child: Text(
                localizedStrings.clearRoles,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Character> _availableRoles(
      CharacterService characterService, ScriptService scriptService) {
    final roles = scriptService
        .resolveCharacters(characterService.allCharacters)
        .where((character) => character.fraction != Fraction.fabled)
        .toList();
    roles.sort((a, b) {
      final fractionCompare =
          _fractionOrder(a.fraction).compareTo(_fractionOrder(b.fraction));
      if (fractionCompare != 0) {
        return fractionCompare;
      }
      return a.name.compareTo(b.name);
    });
    return roles;
  }

  int _fractionOrder(Fraction fraction) {
    switch (fraction) {
      case Fraction.townsfolk:
        return 0;
      case Fraction.outsider:
        return 1;
      case Fraction.minion:
        return 2;
      case Fraction.demon:
        return 3;
      case Fraction.traveller:
        return 4;
      case Fraction.fabled:
        return 5;
      case Fraction.loric:
        return 6;
    }
  }

  Character? _characterByImage(List<Character> characters, String roleImage) {
    for (final character in characters) {
      if (character.image == roleImage) {
        return character;
      }
    }
    return null;
  }

  String _initialsFor(String playerName) {
    final nameParts = playerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (nameParts.isEmpty) {
      return '?';
    }
    if (nameParts.length == 1) {
      return nameParts.first.substring(0, 1).toUpperCase();
    }
    return '${nameParts.first.substring(0, 1)}${nameParts.last.substring(0, 1)}'
        .toUpperCase();
  }

  double _roleBadgeSizeFor(int roleCount) {
    switch (roleCount) {
      case 0:
        return 54;
      case 1:
        return 72;
      case 2:
        return 64;
      case 3:
        return 56;
      default:
        return 50;
    }
  }

  int _imageCacheWidth(BuildContext context, double logicalSize) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return max(48, (logicalSize * devicePixelRatio).round());
  }
}

class _RoleConnectionPainter extends CustomPainter {
  final Map<String, Offset> positions;
  final Map<String, List<String>> duplicateRoles;
  final double playerTokenSize;

  _RoleConnectionPainter({
    required this.positions,
    required this.duplicateRoles,
    required this.playerTokenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duplicateRoles.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final endpointPaint = Paint()..style = PaintingStyle.fill;

    duplicateRoles.forEach((roleImage, playerNames) {
      final playersWithPosition = playerNames
          .where((playerName) => positions[playerName] != null)
          .toList();
      if (playersWithPosition.length < 2) {
        return;
      }

      final roleColor = _roleColor(roleImage);
      paint.color = roleColor.withOpacity(0.62);
      endpointPaint.color = roleColor.withOpacity(0.88);

      for (var i = 0; i < playersWithPosition.length; i++) {
        for (var j = i + 1; j < playersWithPosition.length; j++) {
          final start = positions[playersWithPosition[i]]! +
              Offset(playerTokenSize / 2, playerTokenSize / 2);
          final end = positions[playersWithPosition[j]]! +
              Offset(playerTokenSize / 2, playerTokenSize / 2);
          canvas.drawLine(start, end, paint);
          canvas.drawCircle(start, 4, endpointPaint);
          canvas.drawCircle(end, 4, endpointPaint);
        }
      }
    });
  }

  @override
  bool shouldRepaint(covariant _RoleConnectionPainter oldDelegate) {
    return oldDelegate.playerTokenSize != playerTokenSize ||
        !_sameOffsets(oldDelegate.positions, positions) ||
        !_sameDuplicateRoles(oldDelegate.duplicateRoles, duplicateRoles);
  }

  bool _sameOffsets(Map<String, Offset> a, Map<String, Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  bool _sameDuplicateRoles(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final otherPlayers = b[entry.key];
      if (otherPlayers == null || otherPlayers.length != entry.value.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (otherPlayers[i] != entry.value[i]) {
          return false;
        }
      }
    }
    return true;
  }
}

Color _roleColor(String roleImage) {
  const colors = [
    Color(0xFFE6C229),
    Color(0xFF4CC9F0),
    Color(0xFFF72585),
    Color(0xFF80ED99),
    Color(0xFFFF6B6B),
    Color(0xFFFFB703),
    Color(0xFF9BF6FF),
    Color(0xFFFFADAD),
  ];
  final hash = roleImage.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return colors[hash % colors.length];
}
