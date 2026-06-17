import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../eraser_notifier.dart';
import '../../viewport_notifier.dart';

/// A short, fading trail that follows the stroke eraser (mirrors Excalidraw's
/// `AnimatedTrail`). Lives inside the viewport transform, so trail points are in
/// scene space; stroke width is divided by zoom to keep a constant screen size.
///
/// A [Ticker] drives per-frame repaints so the tail keeps fading even when the
/// pointer is momentarily still. Only mount it while the stroke eraser is active.
class EraserTrailLayer extends ConsumerStatefulWidget {
  const EraserTrailLayer({super.key});

  @override
  ConsumerState<EraserTrailLayer> createState() => _EraserTrailLayerState();
}

class _EraserTrailLayerState extends ConsumerState<EraserTrailLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(eraserTrailProvider);
    final zoom = ref.watch(viewportProvider).zoom;
    return CustomPaint(
      painter: _EraserTrailPainter(points: points, zoom: zoom),
      size: Size.infinite,
    );
  }
}

class _EraserTrailPainter extends CustomPainter {
  final List<EraserTrailPoint> points;
  final double zoom;

  static const int _fadeMs = 220; // matches Excalidraw's ~200ms decay
  static const double _baseWidth = 10.0;

  _EraserTrailPainter({required this.points, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i < points.length; i++) {
      final age = now - points[i].timeMs;
      if (age > _fadeMs) continue;
      final t = (1.0 - age / _fadeMs).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.35 * t)
        ..strokeWidth = (_baseWidth * t) / zoom
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points[i - 1].position, points[i].position, paint);
    }
  }

  @override
  bool shouldRepaint(_EraserTrailPainter oldDelegate) => true;
}
