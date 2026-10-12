import 'package:blood_on_the_clocktower/components/character_avatar.dart';
import 'package:blood_on_the_clocktower/models/character.dart';
import 'package:blood_on_the_clocktower/models/chronicle.dart';
import 'package:blood_on_the_clocktower/services/character_service.dart';
import 'package:blood_on_the_clocktower/utils/role_image_asset.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChronicleTokenTile extends StatelessWidget {
  final ChronicleCharacterSnapshot snapshot;
  final bool showPlayerName;
  final double size;

  const ChronicleTokenTile.actor({
    super.key,
    required this.snapshot,
    this.size = 72,
  }) : showPlayerName = true;

  const ChronicleTokenTile.player({
    super.key,
    required this.snapshot,
    this.size = 64,
  }) : showPlayerName = true;

  const ChronicleTokenTile.character({
    super.key,
    required this.snapshot,
    this.size = 64,
  }) : showPlayerName = false;

  @override
  Widget build(BuildContext context) {
    final character = _resolveCharacter(context.read<CharacterService>());
    final width = size + 10;
    return SizedBox(
      width: width,
      height: size + 16,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (character != null)
            CharacterAvatar(
              character: character,
              showIsSelected: false,
              showName: true,
              size: size,
            )
          else
            _FallbackToken(snapshot: snapshot, size: size),
          if (showPlayerName && snapshot.playerName.isNotEmpty)
            Positioned(
              top: 4,
              child: Container(
                constraints: BoxConstraints(maxWidth: size * 0.9),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF493131),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  snapshot.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Character? _resolveCharacter(CharacterService service) {
    for (final character in service.gameCharacters) {
      if (character.id == snapshot.characterId &&
          character.roleId == snapshot.roleId) {
        return character;
      }
    }
    for (final character in service.allCharacters) {
      if (character.roleId == snapshot.roleId) return character;
    }
    return null;
  }
}

class ChronicleNumberTile extends StatelessWidget {
  final String value;

  const ChronicleNumberTile({super.key, required this.value});

  @override
  Widget build(BuildContext context) => _ResultBadge(
        minWidth: 54,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class ChronicleYesNoTile extends StatelessWidget {
  final bool value;
  final String yesLabel;
  final String noLabel;

  const ChronicleYesNoTile({
    super.key,
    required this.value,
    required this.yesLabel,
    required this.noLabel,
  });

  @override
  Widget build(BuildContext context) => _ResultBadge(
        color: value ? const Color(0xFF315C49) : const Color(0xFF653B48),
        child: Text(
          value ? yesLabel : noLabel,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class ChronicleTextTile extends StatelessWidget {
  final String value;

  const ChronicleTextTile({super.key, required this.value});

  @override
  Widget build(BuildContext context) => _ResultBadge(
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class ChronicleAddTile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Key? actionKey;

  const ChronicleAddTile({
    super.key,
    required this.label,
    required this.onTap,
    this.actionKey,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 62, minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3152).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF67)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, color: Color(0xFFE1C583)),
              const SizedBox(height: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 105),
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
}

class ChronicleEmptyResultTile extends StatelessWidget {
  const ChronicleEmptyResultTile({super.key});

  @override
  Widget build(BuildContext context) => const _ResultBadge(
        child: Icon(Icons.more_horiz, color: Colors.white54),
      );
}

class _ResultBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  final double minWidth;

  const _ResultBadge({
    required this.child,
    this.color = const Color(0xFF4A3B5E),
    this.minWidth = 58,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      );
}

class _FallbackToken extends StatelessWidget {
  final ChronicleCharacterSnapshot snapshot;
  final double size;

  const _FallbackToken({required this.snapshot, required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: const DecorationImage(
            image: AssetImage('assets/images/backgrounds/token.png'),
            fit: BoxFit.cover,
          ),
          border: Border.all(color: Colors.white24),
        ),
        child: snapshot.image.isEmpty
            ? const Icon(Icons.shield_outlined, color: Colors.white)
            : Transform.translate(
                offset: Offset(0, -size * 0.06),
                child: ClipOval(
                  child: Image.asset(
                    roleImageAssetPath(snapshot.image),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
      );
}
