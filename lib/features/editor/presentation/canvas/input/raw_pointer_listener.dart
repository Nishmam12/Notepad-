// Raw pointer listener that captures stylus/touch input with pressure data.

import 'package:flutter/material.dart';

import '../../../domain/models/stroke_point.dart';

/// Callback types for pointer event handling.
typedef PointerPointCallback = void Function(StrokePoint point);
typedef PointerEndCallback = void Function();

class RawPointerListener extends StatelessWidget {
  final Widget child;
  final PointerPointCallback onPointerDown;
  final PointerPointCallback onPointerMove;
  final PointerEndCallback onPointerUp;

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
        onPointerDown(point);
      },
      onPointerMove: (event) {
        final point = _extractPoint(event);
        onPointerMove(point);
      },
      onPointerUp: (_) {
        onPointerUp();
      },
      onPointerCancel: (_) {
        onPointerUp();
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
