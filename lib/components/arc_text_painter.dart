import 'package:flutter/material.dart';
import 'dart:math';

class ArcTextPainter extends CustomPainter {
  final String text;
  final double radius;
  final double fontSize;
  final double arcAngle; // Der Bogenwinkel

  ArcTextPainter({
    required this.text,
    this.radius = 100,
    this.fontSize = 14,
    this.arcAngle = pi / 4, // Bogenwinkel von 45 Grad (anpassen nach Bedarf)
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double angle = -arcAngle * 1.85; // Startwinkel für den Bogen

    for (int i = 0; i < text.length; i++) {
      final character = text[i];
      final charPainter = TextPainter(
        text: TextSpan(
          text: character,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final charWidth = charPainter.size.width;
      final charHeight = charPainter.size.height;

      final x = radius * cos(angle) - charWidth / 2;
      final y = radius * sin(angle) - charHeight / 2;

      charPainter.paint(
          canvas, Offset(size.width / 2 + x, size.height / 2 - y));

      angle += arcAngle / text.length; // Winkel für das nächste Zeichen
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
