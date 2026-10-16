import 'package:flutter/widgets.dart';

/// Vertical positions of the Playground's central controls.
///
/// The Next Phase arrow sits immediately above the nine-dot menu, while
/// Quick Flow reminder tokens occupy the space above that arrow. When the
/// menu expands, the arrow moves up to leave room for its top menu action.
abstract final class PlaygroundCenterPositions {
  static const Offset menu = Offset.zero;
  static const Offset nextPhase = Offset(0, -70);
  static const Offset reminders = Offset(0, -154);
  static const Offset nextPhaseMenuExpanded = Offset(0, -154);

  static Offset nextPhaseFor({required bool menuVisible}) =>
      menuVisible ? nextPhaseMenuExpanded : nextPhase;
}
