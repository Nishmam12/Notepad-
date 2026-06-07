// A single point in a stroke with x, y coordinates and stylus pressure.

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
}
