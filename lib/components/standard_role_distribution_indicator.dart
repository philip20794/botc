import 'dart:ui' show FontFeature;

import 'package:blood_on_the_clocktower/models/standard_role_distribution.dart';
import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

/// Small, non-interactive reminder of the base setup for the current player count.
class StandardRoleDistributionIndicator extends StatelessWidget {
  const StandardRoleDistributionIndicator({
    super.key,
    required this.playerCount,
  });

  final int playerCount;

  @override
  Widget build(BuildContext context) {
    final counts = StandardRoleDistribution.forPlayerCount(playerCount);
    if (counts == null) return const SizedBox.shrink();

    const blue = Color(0xFF7FC5FF);
    const red = Color(0xFFFF8390);

    const textStyle = TextStyle(
      fontFamily: GrimoireTheme.bodyFont,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const slashStyle = TextStyle(
      color: GrimoireColors.secondaryText,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1,
    );

    return IgnorePointer(
      child: Semantics(
        label: 'Standard setup for $playerCount players: '
            '${counts.townsfolk} Townsfolk, ${counts.outsiders} Outsiders, '
            '${counts.minions} Minions, ${counts.demons} Demon'
            '${playerCount > 15 ? ', plus ${playerCount - 15} Travellers' : ''}',
        child: ExcludeSemantics(
          child: DecoratedBox(
            key: const ValueKey('role-notes-standard-distribution'),
            decoration: BoxDecoration(
              color: GrimoireColors.background.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${counts.townsfolk}',
                      key: const ValueKey('role-notes-townsfolk-count'),
                      style: textStyle.copyWith(color: blue)),
                  const Text('/', style: slashStyle),
                  Text('${counts.outsiders}',
                      key: const ValueKey('role-notes-outsider-count'),
                      style: textStyle.copyWith(color: blue)),
                  const Text('/', style: slashStyle),
                  Text('${counts.minions}',
                      key: const ValueKey('role-notes-minion-count'),
                      style: textStyle.copyWith(color: red)),
                  const Text('/', style: slashStyle),
                  Text('${counts.demons}',
                      key: const ValueKey('role-notes-demon-count'),
                      style: textStyle.copyWith(color: red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
