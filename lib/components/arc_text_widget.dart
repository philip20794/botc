import 'package:flutter/material.dart';
import 'arc_text_painter.dart'; // Importiere die Datei, in der ArcTextPainter definiert ist
import 'dart:math';

class ArcTextWidget extends StatelessWidget {
  final String text;

  ArcTextWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(200, 100), // Größe des CustomPaint Widgets
      painter: ArcTextPainter(
        text: text,
        radius: 150, // Radius des Bogens
        fontSize: 12, // Schriftgröße
        arcAngle: pi / 4, // Bogenwinkel (anpassen nach Bedarf)
      ),
    );
  }
}
