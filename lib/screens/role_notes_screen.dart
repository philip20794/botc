import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:blood_on_the_clocktower/components/app_background.dart';
import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
import 'package:blood_on_the_clocktower/screens/role_notes_character_picker_screen.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/services/game_state_service.dart';
import 'package:blood_on_the_clocktower/services/language_service.dart';
import 'package:blood_on_the_clocktower/services/role_notes_service.dart';
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
                  key: ValueKey('role-notes-player-$playerName'),
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
    final characterService =
        Provider.of<CharacterService>(context, listen: false);
    if (characterService.allCharacters.isEmpty) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      await characterService.loadAllCharactersFromJson(languageService.locale);
      if (!context.mounted) return;
    }

    final selectedImages = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => RoleNotesCharacterPickerScreen(playerName: playerName),
      ),
    );
    if (selectedImages == null || !context.mounted) return;
    await Provider.of<RoleNotesService>(context, listen: false)
        .setRolesForPlayer(playerName, selectedImages);
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
