import 'dart:math' as math;
import 'package:flutter/material.dart';

class HalfCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.arcToPoint(
      Offset(size.width, 0),
      radius: Radius.circular(size.width / 2),
      clockwise: true,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HalfCircleTextWidget extends StatelessWidget {
  final String text;
  final double size;

  const HalfCircleTextWidget({Key? key, required this.text, required this.size})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size / 2), // Halbkreisgröße
      painter: HalfCircleTextPainter(text),
    );
  }
}

class HalfCircleTextPainter extends CustomPainter {
  final String text;
  HalfCircleTextPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2.2;
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: radius * 0.4,
    );

    final int letterCount = text.length;
    final totalWidth = getTextWidth(text, radius * 0.4) / (letterCount * 0.5);
    final angleStep = math.asin(totalWidth / (2 * radius));

    final startAngle = angleStep * (letterCount - 1) / 2 - math.pi / 2;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // Berechne den Winkel für jedes Zeichen: Jetzt von π (links) nach 0 (rechts)
      final angle = math.pi - (i * angleStep) + startAngle;

      // Berechne die Position für jedes Zeichen entlang des unteren Halbkreises
      final offsetX = radius + radius * math.cos(angle);
      final offsetY = radius + radius * math.sin(angle);

      // TextPainter nur für das aktuelle Zeichen
      final textPainter = TextPainter(
        text: TextSpan(text: char, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();

      // Verschiebe den Canvas zum berechneten Punkt
      canvas.translate(offsetX, offsetY - radius * size.height * 0.04);

      // Rotiere den Canvas, damit der Text entlang des Halbkreises ausgerichtet ist
      canvas.rotate(angle - math.pi / 2);

      // Zeichne das Zeichen an der aktuellen Position
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));

      canvas.restore();
    }
  }

  double getTextWidth(String text, double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(); // Layout durchführen, um die Größe zu berechnen
    return textPainter.width; // Breite in Pixeln zurückgeben
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
