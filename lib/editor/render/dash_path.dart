// Converts a solid path into a dashed/dotted one via PathMetrics, for the
// dashed and dotted stroke styles.

import 'dart:math' as math;
import 'dart:ui';

class DashPath {
  DashPath._();

  /// Returns a new path made of [dash]-length segments separated by [gap].
  static Path dashed(Path source, {required double dash, required double gap}) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        result.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        distance += dash + gap;
      }
    }
    return result;
  }
}
