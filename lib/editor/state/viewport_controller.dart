// Viewport for the unified canvas — ported from the proven 1.0.2
// `viewport_notifier.dart`. Transform model: screenX = scrollX + zoom * sceneX.

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

  /// Canvas transform: maps scene (x, y) → screen (x, y).
  Matrix4 toMatrix4() {
    final m = Matrix4.identity();
    m.setEntry(0, 0, zoom); // scale X
    m.setEntry(1, 1, zoom); // scale Y
    m.setEntry(0, 3, scrollX); // translate X
    m.setEntry(1, 3, scrollY); // translate Y
    return m;
  }

  /// Screen-space point → scene coordinates.
  Offset toScene(Offset screen) => Offset(
        (screen.dx - scrollX) / zoom,
        (screen.dy - scrollY) / zoom,
      );

  /// Scene-space point → screen coordinates (inverse of [toScene]).
  Offset toViewport(Offset scene) => Offset(
        scene.dx * zoom + scrollX,
        scene.dy * zoom + scrollY,
      );

  Rect toViewportRect(Rect scene) =>
      Rect.fromPoints(toViewport(scene.topLeft), toViewport(scene.bottomRight));
}

class ViewportController extends StateNotifier<ViewportState> {
  static const double minZoom = 0.1;
  static const double maxZoom = 5.0;

  ViewportController() : super(const ViewportState());

  void pan(Offset delta) {
    state = state.copyWith(
      scrollX: state.scrollX + delta.dx,
      scrollY: state.scrollY + delta.dy,
    );
  }

  /// Zoom toward [focalScreen] (screen coords): the scene point under the focal
  /// stays put on screen.
  void zoomAtPoint(double newZoom, Offset focalScreen) {
    final clamped = newZoom.clamp(minZoom, maxZoom);
    final sceneX = (focalScreen.dx - state.scrollX) / state.zoom;
    final sceneY = (focalScreen.dy - state.scrollY) / state.zoom;
    state = state.copyWith(
      zoom: clamped,
      scrollX: focalScreen.dx - clamped * sceneX,
      scrollY: focalScreen.dy - clamped * sceneY,
    );
  }

  void reset() => state = const ViewportState();
}

final viewportProvider =
    StateNotifierProvider.autoDispose<ViewportController, ViewportState>(
  (ref) => ViewportController(),
);
