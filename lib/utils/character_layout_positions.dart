import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The perimeter order and spacing shared by the game and Role Notes boards.
///
/// Positions describe the top-left corner of the main character/player token.
/// Board height includes the centering offset, as in the original game layout.
class CharacterLayoutPositions {
  const CharacterLayoutPositions._();

  static Map<int, Offset> calculate({
    required int count,
    required Size boardSize,
    required double characterSize,
    required double radiusX,
    required double radiusY,
    required double startAngleDiv,
    required double offsetX,
    required double offsetY,
  }) {
    if (count <= 0 || boardSize.isEmpty) return {};

    if (count <= 2) {
      final spacing = characterSize + radiusX;
      final startX = (boardSize.width - (count - 1) * spacing - characterSize) / 2;
      final y = (boardSize.height - characterSize) / 2 + offsetY;
      return {
        for (var i = 0; i < count; i++)
          i: Offset(startX + i * spacing, y),
      };
    }

    final numCols = math.min(count, math.max(2, startAngleDiv.toInt()));
    final numRows = math.max(2, (2 + (count - numCols * 2) / 2).ceil());
    final itemWidth = characterSize + radiusX;
    final itemHeight = characterSize + radiusY;
    final centeredY = (boardSize.height - itemHeight * numRows) / 2;

    final positions = <int, Offset>{};
    void add(int col, int row) {
      if (positions.length >= count) return;
      positions[positions.length] = Offset(
        col * itemWidth + characterSize / 2 + offsetX,
        row * itemHeight + characterSize / 2 + offsetY + centeredY,
      );
    }

    var top = 0;
    var bottom = numRows - 1;
    var left = 0;
    var right = numCols - 1;

    while (top <= bottom && left <= right && positions.length < count) {
      for (var row = bottom; row >= top; row--) {
        add(left, row);
      }
      left++;

      if (top == 0) {
        for (var col = left; col <= right; col++) {
          add(col, top);
        }
      }
      top++;

      for (var row = top; row <= bottom; row++) {
        add(right, row);
      }
      right--;

      if (top <= bottom) {
        for (var col = right; col >= left; col--) {
          add(col, bottom);
        }
        bottom--;
      }
    }
    return positions;
  }
}
