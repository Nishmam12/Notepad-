import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewportState {
  final double scrollX;
  final double scrollY;
  final double zoom;

  const ViewportState({
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.zoom = 1.0,
  });

  ViewportState copyWith({double? scrollX, double? scrollY, double? zoom}) {
    return ViewportState(
      scrollX: scrollX ?? this.scrollX,
      scrollY: scrollY ?? this.scrollY,
      zoom: zoom ?? this.zoom,
    );
  }

  /// Build the canvas transform matrix. Maps scene (x, y) → screen (x, y):
  ///   screenX = scrollX + zoom * sceneX
  Matrix4 toMatrix4() {
    // Set directly to avoid version-specific Matrix4 API deprecations.
    final m = Matrix4.identity();
    m.setEntry(0, 0, zoom);     // scale X
    m.setEntry(1, 1, zoom);     // scale Y
    m.setEntry(0, 3, scrollX);  // translate X
    m.setEntry(1, 3, scrollY);  // translate Y
    return m;
  }

  /// Convert a screen-space point to scene coordinates.
  Offset toScene(Offset screen) {
    return Offset(
      (screen.dx - scrollX) / zoom,
      (screen.dy - scrollY) / zoom,
    );
  }
}

class ViewportNotifier extends StateNotifier<ViewportState> {
  static const double _minZoom = 0.1;
  static const double _maxZoom = 5.0;

  ViewportNotifier() : super(const ViewportState());

  void pan(Offset delta) {
    state = state.copyWith(
      scrollX: state.scrollX + delta.dx,
      scrollY: state.scrollY + delta.dy,
    );
  }

  /// Zoom toward a focal point given in viewport (screen) coordinates.
  /// The scene point under focalScreen stays at the same screen location.
  void zoomAtPoint(double newZoom, Offset focalScreen) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    // Scene point that was under focal before zoom
    final sceneX = (focalScreen.dx - state.scrollX) / state.zoom;
    final sceneY = (focalScreen.dy - state.scrollY) / state.zoom;
    // Keep that scene point under focal after zoom
    state = state.copyWith(
      zoom: clamped,
      scrollX: focalScreen.dx - clamped * sceneX,
      scrollY: focalScreen.dy - clamped * sceneY,
    );
  }

  void reset() => state = const ViewportState();
}

final viewportProvider =
    StateNotifierProvider.autoDispose<ViewportNotifier, ViewportState>(
  (ref) => ViewportNotifier(),
);
