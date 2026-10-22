import 'package:blood_on_the_clocktower/models/responsive_layout_defaults.dart';
import 'package:blood_on_the_clocktower/utils/character_layout_positions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('11-character reference keeps the original perimeter order', () {
    const viewport = Size(360, 708);
    final defaults = ResponsiveLayoutDefaults.forViewport(viewport);
    final positions = CharacterLayoutPositions.calculate(
      count: 11,
      boardSize: viewport,
      characterSize: defaults.characterKnobSize,
      radiusX: defaults.radiusX,
      radiusY: defaults.radiusY,
      startAngleDiv: defaults.startAngleDiv,
      offsetX: defaults.offsetX,
      offsetY: defaults.offsetY,
    );
    final itemHeight = defaults.characterKnobSize + defaults.radiusY;
    final itemWidth = defaults.characterKnobSize + defaults.radiusX;
    final centerY = (viewport.height - itemHeight * 5) / 2;
    final left = defaults.characterKnobSize / 2 + defaults.offsetX;
    final top = defaults.characterKnobSize / 2 + defaults.offsetY + centerY;

    expect(positions, hasLength(11));
    expect(positions[0], Offset(left, top + itemHeight * 4));
    expect(positions[4], Offset(left, top));
    expect(positions[5], Offset(left + itemWidth, top));
    expect(positions[6], Offset(left + itemWidth * 2, top));
    expect(positions[7], Offset(left + itemWidth * 2, top + itemHeight));
    expect(positions[10], Offset(left + itemWidth * 2, top + itemHeight * 4));
  });

  test('handles one, two and eighteen players with a stable position per player', () {
    for (final count in [1, 2, 3, 4, 5, 6, 11, 15, 18]) {
      final positions = CharacterLayoutPositions.calculate(
        count: count,
        boardSize: const Size(393, 852),
        characterSize: 86,
        radiusX: 27,
        radiusY: 60,
        startAngleDiv: 3.8,
        offsetX: -20,
        offsetY: -26,
      );
      expect(positions.length, count);
      expect(positions.keys, orderedEquals(List.generate(count, (i) => i)));
      expect(positions.values.every((p) => p.dx.isFinite && p.dy.isFinite),
          isTrue);
    }
  });
}
