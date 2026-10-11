import 'package:flutter/material.dart';

enum AppBackgroundType { ui, playground }

/// A single, full-screen background image for a screen or a screen body.
///
/// The artwork has a portrait aspect ratio. [BoxFit.cover] keeps the frame
/// filled on the supported phone sizes while only trimming the outer edges on
/// unusually wide displays.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.type = AppBackgroundType.ui,
  });

  final Widget child;
  final AppBackgroundType type;

  static String assetFor(AppBackgroundType type) => switch (type) {
        AppBackgroundType.ui =>
          'assets/images/backgrounds/background_grim_ui.png',
        AppBackgroundType.playground =>
          'assets/images/backgrounds/background_grim_playground.png',
      };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(assetFor(type)),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.high,
        ),
      ),
      child: child,
    );
  }
}
