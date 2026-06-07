// Renders the canvas (background + template + strokes) to PNG or PDF bytes.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../editor/domain/models/stroke.dart';
import '../editor/domain/models/template_type.dart';
import '../editor/presentation/canvas/layers/template_painter.dart';

/// Export resolution: A4 at 300 DPI.
const double _exportWidth = 2480;
const double _exportHeight = 3508;

class CanvasExportService {
  /// Renders the canvas to PNG bytes at A4 300 DPI resolution.
  static Future<Uint8List> exportToPng({
    required List<Stroke> strokes,
    required TemplateType templateType,
    Color backgroundColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, _exportWidth, _exportHeight),
    );
    const size = Size(_exportWidth, _exportHeight);

    // 1. Background fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    // 2. Template pattern
    TemplatePainter.paint(canvas, size, templateType, backgroundColor);

    // 3. Strokes — re-render using perfect_freehand
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 4. Encode to PNG
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _exportWidth.toInt(),
      _exportHeight.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to encode canvas to PNG');
    }

    return byteData.buffer.asUint8List();
  }

  /// Draws a single stroke using perfect_freehand outlines.
  static void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final inputPoints = stroke.points
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList();

    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: stroke.size,
        thinning: 0.5,
        smoothing: 0.5,
        streamline: 0.5,
      ),
    );

    if (outlinePoints.length < 2) return;

    final path = Path();
    path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length - 1; i++) {
      final p0 = outlinePoints[i];
      final p1 = outlinePoints[i + 1];
      path.quadraticBezierTo(
        p0.dx,
        p0.dy,
        (p0.dx + p1.dx) / 2,
        (p0.dy + p1.dy) / 2,
      );
    }

    final paint = Paint()
      ..color = Color(stroke.color).withValues(alpha: stroke.opacity)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }
}
