import 'dart:async';

import 'package:flutter/material.dart';

class PlayerInteractionTarget extends StatelessWidget {
  final bool quickReminderActive;
  final FutureOr<void> Function() onQuickTap;
  final VoidCallback onOpenMenu;
  final Widget child;

  const PlayerInteractionTarget({
    super.key,
    required this.quickReminderActive,
    required this.onQuickTap,
    required this.onOpenMenu,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: quickReminderActive ? onQuickTap : onOpenMenu,
        onLongPress: onOpenMenu,
        child: child,
      );
}
