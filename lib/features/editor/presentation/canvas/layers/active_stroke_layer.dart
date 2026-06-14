// Active stroke layer — draws ONLY the current live in-progress stroke.

import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../../domain/models/stroke_point.dart' as models;

class ActiveStrokeLayer extends CustomPainter {
  final List<models.StrokePoint> currentStrokePoints;
  final Color strokeColor;
  final double strokeSize;
  final double strokeOpacity;
  final bool isEraser;

  const ActiveStrokeLayer({
    required this.currentStrokePoints,
    required this.strokeColor,
    required this.strokeSize,
    this.strokeOpacity = 1.0,
    this.isEraser = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentStrokePoints.isEmpty) return;
    // The pixel eraser erases live in the combined content layer — no trail is
    // drawn here for the eraser.
    if (isEraser) return;

    final paint = Paint()
      ..color = strokeColor.withValues(alpha: strokeOpacity)
      ..style = PaintingStyle.fill;

    final inputPoints = currentStrokePoints
        .map((p) => PointVector(p.x, p.y, p.pressure))
        .toList();

    final simulate = currentStrokePoints.first.simulatePressure;
    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: strokeSize,
        thinning: 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        easing: (t) => sin(t * pi / 2),
        simulatePressure: simulate,
        isComplete: false,
      ),
    );

    if (outlinePoints.isEmpty) return;

    final path = _buildPath(outlinePoints);
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
  bool shouldRepaint(ActiveStrokeLayer oldDelegate) =>
      currentStrokePoints != oldDelegate.currentStrokePoints;
}
