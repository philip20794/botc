import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the 360 x 708 reference exactly reproduces the tuned layout', () {
    final values =
        ResponsiveLayoutDefaults.forViewport(const Size(360, 708));
    expect(ResponsiveLayoutDefaults.previewCharacterCount, 11);
    expect(values.characterKnobSize, closeTo(79.74238389840153, 0.00001));
    expect(values.startAngleDiv, closeTo(3.834969935972998, 0.00001));
    expect(values.radiusX, closeTo(27.347180606397387, 0.00001));
    expect(values.radiusY, closeTo(48.80186513889054, 0.00001));
    expect(values.tokenKnobSize, closeTo(30.237771718779964, 0.00001));
    expect(values.tokenOffsetX, closeTo(36.85723123374895, 0.00001));
    expect(values.tokenOffsetY, closeTo(23.773188678764853, 0.00001));
    expect(values.selectedReminderTokenSize, closeTo(42.0453809492427, 0.00001));
    expect(values.unselectedReminderTokenSize,
        closeTo(29.668719660285067, 0.00001));
    expect(values.offsetX, closeTo(-19.35562976298884, 0.00001));
    expect(values.offsetY, closeTo(-26.276387173705302, 0.00001));
  });

  test('different phone proportions scale spacing independently', () {
    final short = ResponsiveLayoutDefaults.forViewport(const Size(320, 640));
    final tall = ResponsiveLayoutDefaults.forViewport(const Size(360, 800));
    final large = ResponsiveLayoutDefaults.forViewport(const Size(430, 932));

    expect(short.characterKnobSize, closeTo(70.9, 0.2));
    expect(short.radiusX, closeTo(24.3, 0.2));
    expect(short.radiusY, closeTo(45.3, 0.2));
    expect(tall.characterKnobSize, closeTo(79.7, 0.2));
    expect(tall.radiusY, closeTo(65.5, 0.2));
    expect(large.characterKnobSize, closeTo(95.2, 0.2));
    expect(large.radiusX, closeTo(32.7, 0.2));
    expect(large.radiusY, closeTo(74.0, 0.2));
    expect(large.offsetY, closeTo(-29.7, 0.2));
  });

  test('unusual viewports remain within layout slider limits', () {
    for (final size in [
      const Size(200, 300),
      const Size(1100, 2000),
      Size.zero,
    ]) {
      final values = ResponsiveLayoutDefaults.forViewport(size);
      expect(values.characterKnobSize, inInclusiveRange(60, 140));
      expect(values.radiusX, inInclusiveRange(5, 109));
      expect(values.radiusY, inInclusiveRange(30, 235));
      expect(values.tokenKnobSize, inInclusiveRange(10, 60));
      expect(values.offsetX, inInclusiveRange(-145, 55));
      expect(values.offsetY, inInclusiveRange(-185, 25));
    }
  });
}
