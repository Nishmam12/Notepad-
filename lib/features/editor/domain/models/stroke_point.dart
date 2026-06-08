// A single point in a stroke with x, y coordinates and stylus pressure.

import 'dart:ui';

class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  /// Creates a StrokePoint from a map (for deserialization).
  factory StrokePoint.fromMap(Map<String, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: (map['p'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// Converts this point to a map (for serialization).
  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'p': pressure,
    };
  }

  StrokePoint copyWith({
    double? x,
    double? y,
    double? pressure,
  }) {
    return StrokePoint(
      x: x ?? this.x,
      y: y ?? this.y,
      pressure: pressure ?? this.pressure,
    );
  }

  Offset toOffset() => Offset(x, y);
}
