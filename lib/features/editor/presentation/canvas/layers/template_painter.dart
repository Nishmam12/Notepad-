// Paints vector template patterns (ruled, dotted, grid, engineering) onto the canvas.

import 'package:flutter/material.dart';

import '../../../domain/models/template_type.dart';
import '../../../domain/models/template_config.dart';

class TemplatePainter {
  /// Paints the template pattern for the given type onto the canvas.
  static void paint(
    Canvas canvas,
    Size size,
    TemplateType type,
    Color backgroundColor,
  ) {
    if (type == TemplateType.blank) return;

    final config = TemplateConfig.forBackground(type, backgroundColor);

    switch (type) {
      case TemplateType.blank:
        return;
      case TemplateType.ruled:
        _paintRuled(canvas, size, config);
      case TemplateType.dotted:
        _paintDotted(canvas, size, config);
      case TemplateType.grid:
        _paintGrid(canvas, size, config);
      case TemplateType.engineeringGrid:
        _paintEngineeringGrid(canvas, size, config);
    }
  }

  /// Paints horizontal ruled lines with an optional left margin line.
  static void _paintRuled(Canvas canvas, Size size, TemplateConfig config) {
    final linePaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    final marginPaint = Paint()
      ..color = config.marginLineColor
      ..strokeWidth = config.lineWidth * 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal lines
    double y = config.lineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += config.lineSpacing;
    }

    // Left margin line
    canvas.drawLine(
      Offset(config.marginOffset, 0),
      Offset(config.marginOffset, size.height),
      marginPaint,
    );
  }

  /// Paints evenly spaced dots across the canvas.
  static void _paintDotted(Canvas canvas, Size size, TemplateConfig config) {
    final dotPaint = Paint()
      ..color = config.lineColor
      ..style = PaintingStyle.fill;

    double x = config.dotSpacing;
    while (x < size.width) {
      double y = config.dotSpacing;
      while (y < size.height) {
        canvas.drawCircle(Offset(x, y), config.dotRadius, dotPaint);
        y += config.dotSpacing;
      }
      x += config.dotSpacing;
    }
  }

  /// Paints a uniform grid of horizontal and vertical lines.
  static void _paintGrid(Canvas canvas, Size size, TemplateConfig config) {
    final linePaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    // Vertical lines
    double x = config.lineSpacing;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      x += config.lineSpacing;
    }

    // Horizontal lines
    double y = config.lineSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      y += config.lineSpacing;
    }
  }

  /// Paints an engineering grid with minor and major lines.
  static void _paintEngineeringGrid(
    Canvas canvas,
    Size size,
    TemplateConfig config,
  ) {
    final minorPaint = Paint()
      ..color = config.lineColor
      ..strokeWidth = config.lineWidth
      ..style = PaintingStyle.stroke;

    final majorPaint = Paint()
      ..color = config.majorLineColor
      ..strokeWidth = config.majorLineWidth
      ..style = PaintingStyle.stroke;

    // Vertical lines
    int col = 1;
    double x = config.lineSpacing;
    while (x < size.width) {
      final paint = (col % config.majorLineInterval == 0)
          ? majorPaint
          : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += config.lineSpacing;
      col++;
    }

    // Horizontal lines
    int row = 1;
    double y = config.lineSpacing;
    while (y < size.height) {
      final paint = (row % config.majorLineInterval == 0)
          ? majorPaint
          : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += config.lineSpacing;
      row++;
    }
  }
}
