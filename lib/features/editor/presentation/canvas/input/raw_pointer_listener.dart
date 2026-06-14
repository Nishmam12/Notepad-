// Raw pointer listener with palm rejection, pressure extraction, and multi-touch viewport support.
// Inspired by Excalidraw's pointer handling: pen mode rejects simultaneous touch events,
// and two-finger gestures trigger pan/zoom instead of drawing.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../../../domain/models/stroke_point.dart';

typedef PointerEventCallback = void Function(PointerEvent event, StrokePoint point);

// Callback for incremental pan+zoom updates from multi-touch or hand-tool gestures.
// panDelta  — screen-space translation to apply to scrollX/Y.
// focalPoint — current midpoint of the two active pointers (screen coords).
// scaleDelta — multiplicative zoom factor (1.0 = no scale change).
typedef ViewportUpdateCallback = void Function(
  Offset panDelta,
  Offset focalPoint,
  double scaleDelta,
);

class RawPointerListener extends StatefulWidget {
  final Widget child;
  final bool enablePalmRejection;

  // Drawing callbacks (single-pointer, non-hand-tool events).
  final PointerEventCallback onPointerDown;
  final PointerEventCallback onPointerMove;
  final PointerEventCallback onPointerUp;

  // Fired when a second pointer arrives while a stroke is in progress.
  // The host should discard the in-flight stroke to avoid partial draws.
  final VoidCallback? onStrokeCancel;

  // Fired for two-finger pinch/pan and single-finger hand-tool pan.
  final ViewportUpdateCallback? onViewportUpdate;

  // Whether the hand tool is active — single-pointer moves pan instead of draw.
  final bool isHandTool;

  const RawPointerListener({
    super.key,
    required this.child,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    this.enablePalmRejection = true,
    this.onStrokeCancel,
    this.onViewportUpdate,
    this.isHandTool = false,
  });

  @override
  State<RawPointerListener> createState() => _RawPointerListenerState();
}

class _RawPointerListenerState extends State<RawPointerListener> {
  // Pointer IDs of stylus contacts currently on screen (for palm rejection).
  final Set<int> _activeStylusPointers = {};

  // Touch/stylus pointers that were rejected (palm) — ignore their move/up events too.
  final Set<int> _rejectedPointers = {};

  // All non-rejected active pointers and their current positions (screen coords).
  final Map<int, Offset> _activePointers = {};

  // True once a second pointer is confirmed — suppresses drawing until all lift.
  bool _isMultiTouch = false;

  bool _shouldReject(PointerDownEvent event) {
    return widget.enablePalmRejection &&
        event.kind == PointerDeviceKind.touch &&
        _activeStylusPointers.isNotEmpty;
  }

  StrokePoint _extractPoint(PointerEvent event) {
    // pressure == 0.0 → no hardware support; 0.5 is the OS default for non-pressure input.
    final bool simulate = event.pressure == 0.0 || event.pressure == 0.5;
    final double pressure = simulate ? 0.5 : event.pressure.clamp(0.01, 1.0);
    return StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: pressure,
      simulatePressure: simulate,
    );
  }

  // Compute and emit a viewport update when pointer [pointerId] moves to [newPos].
  // The "other" pointer (if any) stays at its last known position.
  void _emitViewportUpdate(int pointerId, Offset oldPos, Offset newPos) {
    if (widget.onViewportUpdate == null) return;

    final otherIds = _activePointers.keys.where((id) => id != pointerId).toList();

    if (otherIds.isNotEmpty) {
      // Two-finger: compute scale + pan between old and new positions.
      final otherPos = _activePointers[otherIds.first]!;

      final oldDist = (oldPos - otherPos).distance;
      final newDist = (newPos - otherPos).distance;
      final scaleDelta = oldDist > 1.0 ? newDist / oldDist : 1.0;

      final oldFocal = (oldPos + otherPos) / 2;
      final newFocal = (newPos + otherPos) / 2;
      final panDelta = newFocal - oldFocal;

      widget.onViewportUpdate!(panDelta, newFocal, scaleDelta);
    } else {
      // Single-finger hand tool: pure pan.
      final panDelta = newPos - oldPos;
      widget.onViewportUpdate!(panDelta, newPos, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // Track stylus pointer IDs for palm rejection.
        if (event.kind == PointerDeviceKind.stylus) {
          _activeStylusPointers.add(event.pointer);
        }

        // Palm rejection: drop touch events while any stylus is active.
        if (_shouldReject(event)) {
          _rejectedPointers.add(event.pointer);
          return;
        }

        final prevCount = _activePointers.length;
        _activePointers[event.pointer] = event.localPosition;

        if (_activePointers.length >= 2 && !_isMultiTouch) {
          // Second pointer arrived — switch to pan/zoom mode.
          _isMultiTouch = true;
          widget.onStrokeCancel?.call();
          return;
        }

        if (_isMultiTouch) return;

        // Hand tool: single pointer pans.
        if (widget.isHandTool) return;

        if (prevCount == 0) {
          final point = _extractPoint(event);
          widget.onPointerDown(event, point);
        }
      },
      onPointerMove: (event) {
        if (_rejectedPointers.contains(event.pointer)) return;

        final oldPos = _activePointers[event.pointer];
        if (oldPos == null) return; // pointer not tracked

        final newPos = event.localPosition;

        if (_isMultiTouch || widget.isHandTool) {
          _emitViewportUpdate(event.pointer, oldPos, newPos);
          _activePointers[event.pointer] = newPos;
          return;
        }

        _activePointers[event.pointer] = newPos;
        final point = _extractPoint(event);
        widget.onPointerMove(event, point);
      },
      onPointerUp: (event) {
        _activeStylusPointers.remove(event.pointer);

        if (_rejectedPointers.remove(event.pointer)) return;

        _activePointers.remove(event.pointer);

        if (_activePointers.isEmpty) {
          _isMultiTouch = false;
        }

        if (_isMultiTouch) return;
        if (widget.isHandTool) return;

        final point = _extractPoint(event);
        widget.onPointerUp(event, point);
      },
      onPointerCancel: (event) {
        _activeStylusPointers.remove(event.pointer);
        _rejectedPointers.remove(event.pointer);
        _activePointers.remove(event.pointer);

        if (_activePointers.isEmpty) {
          _isMultiTouch = false;
        }

        if (_isMultiTouch) return;
        if (widget.isHandTool) return;

        final point = _extractPoint(event);
        widget.onPointerUp(event, point);
      },
      child: widget.child,
    );
  }
}
