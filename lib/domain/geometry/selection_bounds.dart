// Selection bounding box, resize-handle layout, and resize math.
//
// The selection box is the axis-aligned union of the selected elements' world
// bounds. Resize computes a scale factor + fixed anchor for a dragged handle,
// with optional aspect lock (shift) and resize-from-centre (alt).

import 'dart:math' as math;
import 'dart:ui';

import '../model/scene_element.dart';
import 'scene_geometry.dart';

enum HandlePos {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

class ResizeResult {
  final double sx;
  final double sy;
  final Offset anchor;
  const ResizeResult(this.sx, this.sy, this.anchor);
}

class SelectionBounds {
  SelectionBounds._();

  /// Axis-aligned union of the selected elements' world bounds.
  static Rect? union(List<SceneElement> selected) {
    Rect? box;
    for (final e in selected) {
      final b = SceneGeometry.worldAabb(e);
      box = box == null ? b : box.expandToInclude(b);
    }
    return box;
  }

  static Offset handlePoint(HandlePos h, Rect box) {
    switch (h) {
      case HandlePos.topLeft:
        return box.topLeft;
      case HandlePos.top:
        return box.topCenter;
      case HandlePos.topRight:
        return box.topRight;
      case HandlePos.right:
        return box.centerRight;
      case HandlePos.bottomRight:
        return box.bottomRight;
      case HandlePos.bottom:
        return box.bottomCenter;
      case HandlePos.bottomLeft:
        return box.bottomLeft;
      case HandlePos.left:
        return box.centerLeft;
    }
  }

  static Map<HandlePos, Offset> handlePoints(Rect box) =>
      {for (final h in HandlePos.values) h: handlePoint(h, box)};

  /// The fixed point opposite the dragged handle.
  static Offset anchorFor(HandlePos h, Rect box) {
    switch (h) {
      case HandlePos.topLeft:
        return box.bottomRight;
      case HandlePos.top:
        return box.bottomCenter;
      case HandlePos.topRight:
        return box.bottomLeft;
      case HandlePos.right:
        return box.centerLeft;
      case HandlePos.bottomRight:
        return box.topLeft;
      case HandlePos.bottom:
        return box.topCenter;
      case HandlePos.bottomLeft:
        return box.topRight;
      case HandlePos.left:
        return box.centerRight;
    }
  }

  static bool _affectsX(HandlePos h) =>
      h != HandlePos.top && h != HandlePos.bottom;
  static bool _affectsY(HandlePos h) =>
      h != HandlePos.left && h != HandlePos.right;

  /// Computes scale + anchor for dragging [h] to [pointer].
  static ResizeResult resize(
    Rect box,
    HandlePos h,
    Offset pointer, {
    bool aspect = false,
    bool fromCenter = false,
  }) {
    final anchor = fromCenter ? box.center : anchorFor(h, box);
    final handle = handlePoint(h, box);

    double sx = 1, sy = 1;
    if (_affectsX(h)) {
      final old = handle.dx - anchor.dx;
      if (old.abs() > 1e-6) sx = (pointer.dx - anchor.dx) / old;
    }
    if (_affectsY(h)) {
      final old = handle.dy - anchor.dy;
      if (old.abs() > 1e-6) sy = (pointer.dy - anchor.dy) / old;
    }

    if (aspect) {
      if (_affectsX(h) && _affectsY(h)) {
        final s = math.max(sx.abs(), sy.abs());
        sx = s;
        sy = s;
      } else if (_affectsX(h)) {
        sy = sx;
      } else {
        sx = sy;
      }
    }

    // Keep shapes from collapsing or mirroring (Phase 4 has no flip).
    sx = sx.clamp(0.02, 1000.0);
    sy = sy.clamp(0.02, 1000.0);
    return ResizeResult(sx, sy, anchor);
  }
}
