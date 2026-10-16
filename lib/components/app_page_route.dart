import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Standard material navigation with an immediate, non-snapshotting reverse
/// transition in the browser.
///
/// A mobile browser's Back/swipe gesture already animates the page change.
/// Flutter's own reverse MaterialPageRoute animation would keep painting the
/// popped screen for another few frames, which looks like a flash of the
/// previous Settings/Character Selection screen before Home is revealed.
///
/// On native Android (and other non-web targets), keep the original Material
/// route and its platform-specific back transitions unchanged.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    bool? webNavigation,
  }) : _webNavigation = webNavigation ?? kIsWeb;

  final bool _webNavigation;

  @override
  Duration get reverseTransitionDuration =>
      _webNavigation ? Duration.zero : super.reverseTransitionDuration;

  @override
  bool get allowSnapshotting =>
      !_webNavigation && super.allowSnapshotting;
}
