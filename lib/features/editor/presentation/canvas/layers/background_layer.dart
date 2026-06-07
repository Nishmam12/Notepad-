// Background layer — draws canvas background color and template pattern.

import 'package:flutter/material.dart';

import '../../../domain/models/template_type.dart';
import 'template_painter.dart';

class BackgroundLayer extends CustomPainter {
  final Color backgroundColor;
  final TemplateType templateType;

  const BackgroundLayer({
    this.backgroundColor = Colors.white,
    this.templateType = TemplateType.blank,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint background fill.
    final paint = Paint()..color = backgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Paint template overlay.
    TemplatePainter.paint(canvas, size, templateType, backgroundColor);
  }

  @override
  bool shouldRepaint(BackgroundLayer oldDelegate) =>
      backgroundColor != oldDelegate.backgroundColor ||
      templateType != oldDelegate.templateType;
}
