import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

class GrimoirePanel extends StatelessWidget {
  const GrimoirePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.emphasized = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: GrimoireTheme.panelDecoration(emphasized: emphasized),
      child: Padding(padding: padding, child: child),
    );
  }
}

class GrimoireSectionHeading extends StatelessWidget {
  const GrimoireSectionHeading({
    super.key,
    required this.title,
    this.icon,
  });

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: GrimoireColors.antiqueGold, size: 18),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: GrimoireColors.antiqueGold,
                  letterSpacing: 0.7,
                ),
          ),
        ),
      ],
    );
  }
}

class GrimoireBackgroundVeil extends StatelessWidget {
  const GrimoireBackgroundVeil({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x88100C16),
              Color(0x38100C16),
              Color(0xA8100C16),
            ],
            stops: [0, 0.42, 1],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}
