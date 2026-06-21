// Alignment snapping while dragging: snaps the moving selection box's edges and
// centres to other elements' edges/centres, returning a corrective offset plus
// the guide lines to draw. All coordinates are scene-space.

import 'dart:math' as math;
import 'dart:ui';

class SnapGuide {
  final Offset a;
  final Offset b;
  const SnapGuide(this.a, this.b);
}

class SnapResult {
  /// Extra offset to add to the already-applied drag so edges line up.
  final Offset adjust;
  final List<SnapGuide> guides;
  const SnapResult(this.adjust, this.guides);

  static const none = SnapResult(Offset.zero, []);
}

class SnapEngine {
  SnapEngine._();

  /// [moving] is the selection box at its current (post-drag) position;
  /// [targets] are other elements' world boxes. [threshold] is in scene units
  /// (pass screenThreshold / zoom).
  static SnapResult snap(Rect moving, List<Rect> targets, double threshold) {
    if (targets.isEmpty) return SnapResult.none;

    final movingXs = [moving.left, moving.center.dx, moving.right];
    final movingYs = [moving.top, moving.center.dy, moving.bottom];

    double bestXDist = threshold, bestYDist = threshold;
    double xAdjust = 0, yAdjust = 0;
    double? guideXAt, guideYAt;
    Rect? guideXTarget, guideYTarget;

    for (final t in targets) {
      for (final tx in [t.left, t.center.dx, t.right]) {
        for (final mx in movingXs) {
          final d = (tx - mx).abs();
          if (d <= bestXDist) {
            bestXDist = d;
            xAdjust = tx - mx;
            guideXAt = tx;
            guideXTarget = t;
          }
        }
      }
      for (final ty in [t.top, t.center.dy, t.bottom]) {
        for (final my in movingYs) {
          final d = (ty - my).abs();
          if (d <= bestYDist) {
            bestYDist = d;
            yAdjust = ty - my;
            guideYAt = ty;
            guideYTarget = t;
          }
        }
      }
    }

    final adjust = Offset(xAdjust, yAdjust);
    final snapped = moving.shift(adjust);
    final guides = <SnapGuide>[];
    final gx = guideXAt, gxt = guideXTarget;
    if (gx != null && gxt != null) {
      final top = math.min(snapped.top, gxt.top);
      final bottom = math.max(snapped.bottom, gxt.bottom);
      guides.add(SnapGuide(Offset(gx, top), Offset(gx, bottom)));
    }
    final gy = guideYAt, gyt = guideYTarget;
    if (gy != null && gyt != null) {
      final left = math.min(snapped.left, gyt.left);
      final right = math.max(snapped.right, gyt.right);
      guides.add(SnapGuide(Offset(left, gy), Offset(right, gy)));
    }
    return SnapResult(adjust, guides);
  }
}
