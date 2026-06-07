// A complete stroke consisting of multiple points with visual properties.

import 'stroke_point.dart';

class Stroke {
  final String id;
  final int color;
  final double size;
  final double opacity;
  final List<StrokePoint> points;

  const Stroke({
    required this.id,
    required this.color,
    required this.size,
    this.opacity = 1.0,
    required this.points,
  });

  /// Creates a Stroke from a map (for deserialization).
  factory Stroke.fromMap(Map<String, dynamic> map) {
    return Stroke(
      id: map['id'] as String,
      color: map['color'] as int,
      size: (map['size'] as num).toDouble(),
      opacity: (map['opacity'] as num?)?.toDouble() ?? 1.0,
      points: (map['points'] as List<dynamic>)
          .map((p) => StrokePoint.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converts this stroke to a map (for serialization).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'color': color,
      'size': size,
      'opacity': opacity,
      'points': points.map((p) => p.toMap()).toList(),
    };
  }

  /// Returns a copy of this stroke with the given fields replaced.
  Stroke copyWith({
    String? id,
    int? color,
    double? size,
    double? opacity,
    List<StrokePoint>? points,
  }) {
    return Stroke(
      id: id ?? this.id,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      points: points ?? this.points,
    );
  }
}
