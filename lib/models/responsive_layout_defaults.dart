import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layout calibrated from a 360 x 708 dp portrait viewport with 11 characters.
/// The spacing calculation matches CharacterCircleComponent: each step is the
/// knob size plus the radius. Separately scaling horizontal and vertical steps
/// preserves the reference positions on phones of different aspect ratios.
@immutable
class ResponsiveLayoutDefaults {
  const ResponsiveLayoutDefaults({
    required this.characterKnobSize,
    required this.startAngleDiv,
    required this.radiusX,
    required this.radiusY,
    required this.tokenKnobSize,
    required this.tokenOffsetX,
    required this.tokenOffsetY,
    required this.selectedReminderTokenSize,
    required this.unselectedReminderTokenSize,
    required this.offsetX,
    required this.offsetY,
  });

  static const referenceViewport = Size(360, 708);
  static const previewCharacterCount = 11;

  // Calibrated values from the user's 360 x 708 dp layout.
  static const _character = 79.74238389840153;
  static const _angle = 3.834969935972998;
  static const _radiusX = 27.347180606397387;
  static const _radiusY = 48.80186513889054;
  static const _token = 30.237771718779964;
  static const _tokenX = 36.85723123374895;
  static const _tokenY = 23.773188678764853;
  static const _reminderSelected = 42.0453809492427;
  static const _reminderUnselected = 29.668719660285067;
  static const _offsetX = -19.35562976298884;
  static const _offsetY = -26.276387173705302;

  final double characterKnobSize;
  final double startAngleDiv;
  final double radiusX;
  final double radiusY;
  final double tokenKnobSize;
  final double tokenOffsetX;
  final double tokenOffsetY;
  final double selectedReminderTokenSize;
  final double unselectedReminderTokenSize;
  final double offsetX;
  final double offsetY;

  static double _within(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  factory ResponsiveLayoutDefaults.forViewport(Size viewport) {
    // Invalid/zero viewport metrics can occur during a web app's first frame.
    final width = viewport.width > 0 && viewport.width.isFinite
        ? viewport.width
        : referenceViewport.width;
    final height = viewport.height > 0 && viewport.height.isFinite
        ? viewport.height
        : referenceViewport.height;
    final widthScale = width / referenceViewport.width;
    final heightScale = height / referenceViewport.height;
    final knobScale = math.min(widthScale, heightScale);

    // Clamp to the same limits as the Layout Settings sliders. For unusually
    // narrow/tall windows the exact geometric similarity may be limited.
    final knob = _within(_character * knobScale, 60, 140);
    final stepX = (_character + _radiusX) * widthScale;
    final stepY = (_character + _radiusY) * heightScale;

    return ResponsiveLayoutDefaults(
      characterKnobSize: knob,
      startAngleDiv: _angle,
      radiusX: _within(stepX - knob, 5, 109),
      radiusY: _within(stepY - knob, 30, 235),
      tokenKnobSize: _within(_token * knobScale, 10, 60),
      tokenOffsetX: _within(_tokenX * knobScale, -35, 70),
      tokenOffsetY: _within(_tokenY * knobScale, -40, 80),
      selectedReminderTokenSize:
          _within(_reminderSelected * knobScale, 24, 80),
      unselectedReminderTokenSize:
          _within(_reminderUnselected * knobScale, 12, 48),
      // The positioned character uses knob / 2 as its origin. Account for
      // changes in knob size so the actual positions scale with the viewport.
      offsetX: _within(
        _offsetX * widthScale + (_character * widthScale - knob) / 2,
        -145, 55,
      ),
      offsetY: _within(
        _offsetY * heightScale + (_character * heightScale - knob) / 2,
        -185, 25,
      ),
    );
  }
}
