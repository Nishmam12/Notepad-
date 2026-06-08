// Raw pointer listener that captures stylus/touch input with pressure data.

import 'package:flutter/material.dart';

import '../../../domain/models/stroke_point.dart';

/// Callback types for pointer event handling.
typedef PointerEventCallback = void Function(PointerEvent event, StrokePoint point);

class RawPointerListener extends StatelessWidget {
  final Widget child;
  final PointerEventCallback onPointerDown;
  final PointerEventCallback onPointerMove;
  final PointerEventCallback onPointerUp;

  const RawPointerListener({
    super.key,
    required this.child,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        final point = _extractPoint(event);
        onPointerDown(event, point);
      },
      onPointerMove: (event) {
        final point = _extractPoint(event);
        onPointerMove(event, point);
      },
      onPointerUp: (event) {
        final point = _extractPoint(event);
        onPointerUp(event, point);
      },
      onPointerCancel: (event) {
        final point = _extractPoint(event);
        onPointerUp(event, point);
      },
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  /// Extracts a StrokePoint from a raw PointerEvent, including pressure.
  StrokePoint _extractPoint(PointerEvent event) {
    // Pressure is 0.0–1.0 on supported devices, defaults to 0.5 if unavailable.
    final pressure = event.pressure > 0.0 ? event.pressure : 0.5;

    return StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: pressure,
    );
  }
}
