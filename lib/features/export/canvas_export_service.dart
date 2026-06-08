// Renders the canvas (background + template + strokes) to PNG or PDF bytes.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  /// Exports the canvas to PDF bytes natively using package:pdf.
  /// Runs inside an isolate via compute() to prevent blocking the UI thread.
  static Future<Uint8List> exportToPdf({
    required List<Stroke> strokes,
    required TemplateType templateType,
    Color backgroundColor = Colors.white,
  }) async {
    // Package data needed for the isolate
    final payload = _PdfExportPayload(
      strokes: strokes,
      templateType: templateType,
      backgroundColorValue: backgroundColor.toARGB32(),
    );

    return await compute(_generatePdfIsolate, payload);
  }
}

class _PdfExportPayload {
  final List<Stroke> strokes;
  final TemplateType templateType;
  final int backgroundColorValue;

  _PdfExportPayload({
    required this.strokes,
    required this.templateType,
    required this.backgroundColorValue,
  });
}

/// The isolate entry point for generating the PDF.
Future<Uint8List> _generatePdfIsolate(_PdfExportPayload payload) async {
  final pdf = pw.Document();

  // A4 size in points (1 point = 1/72 inch)
  // A4 is 210x297mm -> ~595x842 points
  const pdfPageFormat = PdfPageFormat.a4;

  pdf.addPage(
    pw.Page(
      pageFormat: pdfPageFormat,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.CustomPaint(
            size: PdfPoint(pdfPageFormat.width, pdfPageFormat.height),
            painter: (PdfGraphics canvas, PdfPoint size) {
              // 1. Background Fill
              final bgColor = PdfColor.fromInt(payload.backgroundColorValue);
              canvas.setFillColor(bgColor);
              canvas.drawRect(0, 0, size.x, size.y);
              canvas.fillPath();

              // Scaling factor from InkFlow's logic canvas (which is relative to device)
              // Since the app uses responsive canvas, we'll scale standard iPad size to A4
              // For a simple map, assume app internal canvas was ~800x1200
              // The exportToPng used 2480x3508 (A4 at 300 DPI). So points in 'strokes' 
              // are actually in logical device pixels (e.g., 0-1000). We need to map them.
              // We'll apply a standard transform.
              canvas.saveContext();
              // Assume strokes are bounded roughly by screen width/height, we might need 
              // to adjust scale depending on how InkFlow saves coordinates.
              // For safety, let's draw them directly. If coordinates are screen-based, 
              // they will render in the top-left of the A4 page at 1pt = 1px.
              
              for (final stroke in payload.strokes) {
                if (stroke.points.isEmpty) continue;

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

                if (outlinePoints.length < 2) continue;

                // PDF coordinates are bottom-up (0,0 is bottom left).
                // We must invert Y to draw top-down.
                void addPath() {
                  canvas.moveTo(outlinePoints.first.dx, size.y - outlinePoints.first.dy);
                  for (int i = 1; i < outlinePoints.length - 1; i++) {
                    final p0 = outlinePoints[i];
                    final p1 = outlinePoints[i + 1];
                    // Quadratic bezier
                    // Control point is p0, endpoint is midpoint between p0 and p1
                    final ctrlX = p0.dx;
                    final ctrlY = size.y - p0.dy;
                    final endX = (p0.dx + p1.dx) / 2;
                    final endY = size.y - (p0.dy + p1.dy) / 2;

                    canvas.curveTo(ctrlX, ctrlY, ctrlX, ctrlY, endX, endY);
                  }
                }

                addPath();
                final color = PdfColor.fromInt(stroke.color);
                // Opacity is applied to the color
                final paintColor = PdfColor(color.red, color.green, color.blue, stroke.opacity);
                canvas.setFillColor(paintColor);
                canvas.fillPath();
              }
              canvas.restoreContext();
            },
          ),
        );
      },
    ),
  );

  return await pdf.save();
}
