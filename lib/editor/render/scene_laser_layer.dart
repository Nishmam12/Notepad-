// Ephemeral laser-pointer trail (scene coordinates). Points fade out by age;
// nothing is persisted. Driven by a ticker in the canvas that prunes old points.

import 'package:flutter/material.dart';

class LaserPoint {
  final Offset position; // scene coords
  final int addedMs; // DateTime.now().millisecondsSinceEpoch
  const LaserPoint(this.position, this.addedMs);
}

class SceneLaserLayer extends CustomPainter {
  final List<LaserPoint> points;
  final int nowMs;
  final int fadeMs;
  final Color color;
  final double width;

  const SceneLaserLayer({
    required this.points,
    required this.nowMs,
    this.fadeMs = 700,
    this.color = const Color(0xFFFF3B30),
    this.width = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    for (int i = 1; i < points.length; i++) {
      final age = nowMs - points[i].addedMs;
      if (age > fadeMs) continue;
      final alpha = (1 - age / fadeMs).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(points[i - 1].position, points[i].position, paint);
    }
  }

  @override
  bool shouldRepaint(SceneLaserLayer old) =>
      !identical(points, old.points) || nowMs != old.nowMs;
}
