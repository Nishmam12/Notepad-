// Screen-space selection overlay: selection box, 8 resize handles, the rotate
// handle, the marquee rectangle, and snap guides. Drawn outside the viewport
// transform so handles stay a constant on-screen size at any zoom.

import 'package:flutter/material.dart';

const double kHandleSize = 9.0;
const double kHandleHitRadius = 16.0;
const double kRotateGap = 26.0;

class SelectionOverlayLayer extends CustomPainter {
  final Rect? boxScreen;
  final List<Offset> handleScreen;
  final Offset? rotateScreen;
  final Rect? marqueeScreen;
  final List<(Offset, Offset)> guides;
  final Color accent;

  const SelectionOverlayLayer({
    this.boxScreen,
    this.handleScreen = const [],
    this.rotateScreen,
    this.marqueeScreen,
    this.guides = const [],
    this.accent = const Color(0xFF6741D9),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Snap guides.
    final guidePaint = Paint()
      ..color = const Color(0xFFE8590C)
      ..strokeWidth = 1;
    for (final (a, b) in guides) {
      canvas.drawLine(a, b, guidePaint);
    }

    // Marquee.
    final marquee = marqueeScreen;
    if (marquee != null) {
      canvas.drawRect(
          marquee, Paint()..color = accent.withValues(alpha: 0.12));
      canvas.drawRect(
        marquee,
        Paint()
          ..color = accent.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Selection box + handles.
    final box = boxScreen;
    if (box != null) {
      canvas.drawRect(
        box,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final rotate = rotateScreen;
      if (rotate != null) {
        canvas.drawLine(
            box.topCenter,
            rotate,
            Paint()
              ..color = accent
              ..strokeWidth = 1.5);
        canvas.drawCircle(rotate, kHandleSize / 2 + 1, Paint()..color = accent);
        canvas.drawCircle(
            rotate, kHandleSize / 2 - 1, Paint()..color = Colors.white);
      }

      final fill = Paint()..color = Colors.white;
      final border = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final h in handleScreen) {
        final r = Rect.fromCenter(
            center: h, width: kHandleSize, height: kHandleSize);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, border);
      }
    }
  }

  @override
  bool shouldRepaint(SelectionOverlayLayer old) =>
      boxScreen != old.boxScreen ||
      rotateScreen != old.rotateScreen ||
      marqueeScreen != old.marqueeScreen ||
      !identical(handleScreen, old.handleScreen) ||
      !identical(guides, old.guides);
}
