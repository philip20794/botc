import 'package:blood_on_the_clocktower/theme/grimoire_theme.dart';
import 'package:flutter/material.dart';

class GrimoirePanel extends StatelessWidget {
  const GrimoirePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.emphasized = false,
    this.surfaceOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool emphasized;
  final double? surfaceOpacity;

  @override
  Widget build(BuildContext context) {
    final decoration = GrimoireTheme.panelDecoration(emphasized: emphasized);
    return DecoratedBox(
      decoration: surfaceOpacity == null
          ? decoration
          : decoration.copyWith(
              color: GrimoireColors.surface.withValues(alpha: surfaceOpacity!),
            ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A restrained, tappable surface for management and preparation screens.
/// It deliberately leaves game tokens and their interaction untouched.
class GrimoirePressablePanel extends StatefulWidget {
  const GrimoirePressablePanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.emphasized = false,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool emphasized;
  final bool enabled;

  @override
  State<GrimoirePressablePanel> createState() => _GrimoirePressablePanelState();
}

class _GrimoirePressablePanelState extends State<GrimoirePressablePanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled && widget.onTap != null;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final decoration = GrimoireTheme.panelDecoration(
      emphasized: widget.emphasized || _pressed,
    ).copyWith(
      color: enabled
          ? GrimoireColors.surface.withValues(alpha: _pressed ? 0.98 : 0.90)
          : GrimoireColors.surface.withValues(alpha: 0.55),
    );
    return Semantics(
      button: enabled,
      enabled: enabled,
      child: AnimatedScale(
        duration: duration,
        scale: _pressed ? 0.985 : 1,
        child: AnimatedContainer(
          duration: duration,
          decoration: decoration,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? widget.onTap : null,
              onHighlightChanged: enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
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
