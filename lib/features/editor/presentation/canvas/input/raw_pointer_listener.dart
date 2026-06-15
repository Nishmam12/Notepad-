// Raw pointer listener with palm rejection, pressure extraction, and multi-touch viewport support.
// Inspired by Excalidraw's pointer handling: pen mode rejects simultaneous touch events,
// and two-finger gestures trigger pan/zoom instead of drawing.
//
// Palm rejection is order-independent. A touch is treated as palm and ignored when a stylus
// is on screen OR was active within the last [_palmRejectionGrace]. When the pen lands after
// the palm (the common case), any touch pointers already down are dropped retroactively and
// their stray stroke is discarded. The grace window also covers a palm that lingers or
// re-taps in the gaps between strokes.

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
  // How long after the last stylus contact touches are still treated as palm.
  // Covers a palm that lingers or re-taps between strokes once the pen lifts.
  static const Duration _palmRejectionGrace = Duration(milliseconds: 500);

  // Pointer IDs of stylus contacts currently on screen (for palm rejection).
  final Set<int> _activeStylusPointers = {};

  // Touch/stylus pointers that were rejected (palm) — ignore their move/up events too.
  final Set<int> _rejectedPointers = {};

  // All non-rejected active pointers and their current positions (screen coords).
  final Map<int, Offset> _activePointers = {};

  // True once a second pointer is confirmed — suppresses drawing until all lift.
  bool _isMultiTouch = false;

  // Engine timestamp of the most recent stylus down/move/up, or null if a stylus
  // has never been seen. Used for the post-lift grace window. Monotonic, so it is
  // immune to wall-clock changes.
  Duration? _lastStylusActivity;

  bool _shouldRejectTouch(PointerEvent event) {
    if (!widget.enablePalmRejection) return false;
    if (event.kind != PointerDeviceKind.touch) return false;
    // A stylus is physically on screen → every touch is palm.
    if (_activeStylusPointers.isNotEmpty) return true;
    // Just lifted the pen → keep rejecting briefly while the palm settles/lifts.
    final lastStylus = _lastStylusActivity;
    if (lastStylus != null && event.timeStamp - lastStylus < _palmRejectionGrace) {
      return true;
    }
    return false;
  }

  // The pen just landed: any touch pointers already on screen are the palm that
  // touched down first. Drop them and discard whatever stray stroke they started
  // so the stylus can draw cleanly.
  void _rejectActiveTouchPointers() {
    final touchIds = _activePointers.keys
        .where((id) => !_activeStylusPointers.contains(id))
        .toList();
    if (touchIds.isEmpty) return;

    for (final id in touchIds) {
      _activePointers.remove(id);
      _rejectedPointers.add(id);
    }
    // Clear any partial finger stroke / multi-touch preview the palm produced.
    widget.onStrokeCancel?.call();
    if (_activePointers.isEmpty) _isMultiTouch = false;
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
          _lastStylusActivity = event.timeStamp;
          // Palm-before-pen: discard any touch already down (and its stray stroke).
          _rejectActiveTouchPointers();
        }

        // Palm rejection: drop touch events while a stylus is active or just lifted.
        if (_shouldRejectTouch(event)) {
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
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
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
        if (event.kind == PointerDeviceKind.stylus) {
          // Start the grace window from the moment the pen lifts.
          _lastStylusActivity = event.timeStamp;
        }
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
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
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
      onPointerHover: (event) {
        // A hovering stylus (e.g. S-Pen near the screen) means the pen is about
        // to write — pre-arm the grace window so a palm landing just before
        // contact is rejected immediately, not retroactively.
        if (event.kind == PointerDeviceKind.stylus) {
          _lastStylusActivity = event.timeStamp;
        }
      },
      child: widget.child,
    );
  }
}
