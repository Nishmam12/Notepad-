// Stroke history layer — draws all completed strokes using perfect_freehand.

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../../domain/models/stroke.dart';

// A cache for generated paths to prevent recalculating `perfect_freehand` every frame.
final Map<String, Path> _pathCache = {};

class StrokeHistoryLayer extends CustomPainter {
  final List<Stroke> strokes;

  const StrokeHistoryLayer({
    required this.strokes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use saveLayer to ensure BlendMode.clear only punches holes in the strokes layer,
    // leaving the underlying background/templates completely intact.
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser 
          ? Colors.transparent 
          : Color(stroke.color).withValues(alpha: stroke.opacity)
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
      ..style = PaintingStyle.fill;

    Path? path = _pathCache[stroke.id];
    if (path == null) {
      final inputPoints = stroke.points
          .map((p) => PointVector(p.x, p.y, p.pressure))
          .toList();

      final outlinePoints = getStroke(
        inputPoints,
        options: StrokeOptions(
          size: stroke.size,
          thinning: 0.7,
          smoothing: 0.5,
          streamline: 0.5,
          simulatePressure: false,
          isComplete: true,
        ),
      );

      if (outlinePoints.isEmpty) return;
      path = _buildPath(outlinePoints);
      _pathCache[stroke.id] = path;
    }

    canvas.drawPath(path, paint);
  }

  Path _buildPath(List<Offset> points) {
    final path = Path();

    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }

    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(StrokeHistoryLayer oldDelegate) =>
      strokes != oldDelegate.strokes;
}
