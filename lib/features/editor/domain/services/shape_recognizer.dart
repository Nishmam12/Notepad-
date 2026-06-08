import 'dart:math';
import 'package:flutter/material.dart';
import '../models/shape_type.dart';
import 'shape_geometry.dart';

class RecognitionResult {
  final ShapeType type;
  final List<double> geometryData;
  const RecognitionResult(this.type, this.geometryData);
}

// Top-level function — safe to pass to compute()
RecognitionResult? recogniseShape(List<Offset> rawPoints) {
  if (rawPoints.length < 6) return null;

  final simplifiedPoints = ShapeGeometry.rdpSimplify(rawPoints, 8.0);

  // LINE CHECK
  final r2 = ShapeGeometry.linearR2(rawPoints);
  if (r2 > 0.93) {
    final first = rawPoints.first;
    final last = rawPoints.last;
    
    // ARROW CHECK (only if LINE CHECK passes)
    if (simplifiedPoints.length >= 3) {
      final secondToLast = simplifiedPoints[simplifiedPoints.length - 2];
      // Compute direction vector of the main line end
      final lineVec = last - secondToLast;
      final lineAngle = atan2(lineVec.dy, lineVec.dx);
      
      // Arrowhead typically has lines drawn back from the tip
      // However, freehand arrows usually involve drawing the line, then the tip as a V shape.
      // The prompt says: compute vectors from second-to-last to last and from second-to-last to third-to-last.
      // If the angle is < 45° (acute V shape), it is an arrow.
      if (simplifiedPoints.length >= 3) {
        final v1 = last - secondToLast;
        final v2 = simplifiedPoints[simplifiedPoints.length - 3] - secondToLast;
        
        final angle = ShapeGeometry.angleBetween(last, secondToLast, simplifiedPoints[simplifiedPoints.length - 3]);
        
        // 45 degrees in radians is ~0.785
        if (angle < 0.785) {
            // Draw standard arrowhead instead of using user's messy arrowhead points to make it look clean.
            // Wait, prompt: "Add arrowhead data to geometryData." 
            // We can just add the two arrow tip points.
            final tip1 = last + Offset(cos(lineAngle + pi*3/4), sin(lineAngle + pi*3/4)) * 20;
            final tip2 = last + Offset(cos(lineAngle - pi*3/4), sin(lineAngle - pi*3/4)) * 20;
            return RecognitionResult(
              ShapeType.arrow, 
              [first.dx, first.dy, last.dx, last.dy, tip1.dx, tip1.dy, tip2.dx, tip2.dy]
            );
        }
      }
    }
    
    return RecognitionResult(ShapeType.line, [first.dx, first.dy, last.dx, last.dy]);
  }

  // CIRCLE CHECK
  final closed = ShapeGeometry.isClosed(simplifiedPoints, 30.0);
  if (closed && simplifiedPoints.length >= 8) {
    final centroid = ShapeGeometry.centroid(rawPoints);
    double sumDist = 0;
    for (final p in rawPoints) {
      sumDist += (p - centroid).distance;
    }
    final avgRadius = sumDist / rawPoints.length;
    
    double variance = 0;
    for (final p in rawPoints) {
      final dist = (p - centroid).distance;
      variance += pow(dist - avgRadius, 2);
    }
    variance /= rawPoints.length;

    if (avgRadius > 0 && (variance / avgRadius) < 0.15) {
      return RecognitionResult(
        ShapeType.circle, 
        [centroid.dx - avgRadius, centroid.dy - avgRadius, centroid.dx + avgRadius, centroid.dy + avgRadius]
      );
    }
  }

  // RECTANGLE CHECK
  if (closed) {
    final rectPoints = ShapeGeometry.rdpSimplify(simplifiedPoints, 15.0);
    // 4 corners means 5 points (since it's closed, first == last)
    if (rectPoints.length == 5) {
      bool isRect = true;
      for (int i = 0; i < 4; i++) {
        final a = rectPoints[i];
        final vertex = rectPoints[(i + 1) % 4];
        final b = rectPoints[(i + 2) % 4];
        final angle = ShapeGeometry.angleBetween(a, vertex, b);
        // 90 degrees is pi/2 (~1.57 radians). 20 degrees is ~0.35 radians.
        if ((angle - pi / 2).abs() > 0.35) {
          isRect = false;
          break;
        }
      }
      
      if (isRect) {
        final rect = ShapeGeometry.boundingRect(rectPoints);
        return RecognitionResult(ShapeType.rectangle, [rect.left, rect.top, rect.right, rect.bottom]);
      }
    }
  }

  // TRIANGLE CHECK
  if (closed) {
    final triPoints = ShapeGeometry.rdpSimplify(simplifiedPoints, 15.0);
    // 3 corners means 4 points
    if (triPoints.length == 4) {
      return RecognitionResult(ShapeType.triangle, [
        triPoints[0].dx, triPoints[0].dy,
        triPoints[1].dx, triPoints[1].dy,
        triPoints[2].dx, triPoints[2].dy,
      ]);
    }
  }

  // POLYGON CHECK (fallback for closed shapes)
  if (closed) {
    final polyPoints = ShapeGeometry.rdpSimplify(simplifiedPoints, 12.0);
    // Remove the last point if it's the same as the first one to avoid duplicate vertex
    int len = polyPoints.length;
    if (len > 0 && (polyPoints.first - polyPoints.last).distance < 1.0) {
       len--;
    }
    
    if (len >= 5 && len <= 12) {
      final List<double> geom = [];
      for (int i=0; i<len; i++) {
        geom.add(polyPoints[i].dx);
        geom.add(polyPoints[i].dy);
      }
      return RecognitionResult(ShapeType.polygon, geom);
    }
  }

  return null;
}
