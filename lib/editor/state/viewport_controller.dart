// Viewport for the unified canvas — ported from the proven 1.0.2
// `viewport_notifier.dart`. Transform model: screenX = scrollX + zoom * sceneX.
//
// Supports two layout modes (see [configure]): an infinite whiteboard (free
// pan, wide zoom range) and a single bounded page (zoom limited to 50–300% and
// pan clamped so the page stays in view / centred when it is smaller than the
// viewport).

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
  static const double infiniteMinZoom = 0.1;
  static const double infiniteMaxZoom = 5.0;
  static const double pageMinZoom = 0.5;
  static const double pageMaxZoom = 3.0;

  ViewportController() : super(const ViewportState());

  // Current layout constraints. In infinite mode [_pageMode] is false and pan
  // is unconstrained; in page mode the page rect / viewport size drive clamping.
  bool _pageMode = false;
  Size _pageSize = Size.zero;
  Size _viewportSize = Size.zero;
  double _minZoom = infiniteMinZoom;
  double _maxZoom = infiniteMaxZoom;

  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;

  /// Sets the active layout mode and the page / viewport geometry used for
  /// clamping, then re-applies constraints to the current state. Called by the
  /// canvas whenever the mode or its size changes.
  void configure({
    required bool pageMode,
    required Size pageSize,
    required Size viewportSize,
  }) {
    final changed = _pageMode != pageMode ||
        _pageSize != pageSize ||
        _viewportSize != viewportSize;
    if (!changed) return;

    _pageMode = pageMode;
    _pageSize = pageSize;
    _viewportSize = viewportSize;
    _minZoom = pageMode ? pageMinZoom : infiniteMinZoom;
    _maxZoom = pageMode ? pageMaxZoom : infiniteMaxZoom;

    final z = state.zoom.clamp(_minZoom, _maxZoom);
    state = _constrain(state.copyWith(zoom: z));
  }

  void pan(Offset delta) {
    state = _constrain(state.copyWith(
      scrollX: state.scrollX + delta.dx,
      scrollY: state.scrollY + delta.dy,
    ));
  }

  /// Zoom toward [focalScreen] (screen coords): the scene point under the focal
  /// stays put on screen.
  void zoomAtPoint(double newZoom, Offset focalScreen) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    final sceneX = (focalScreen.dx - state.scrollX) / state.zoom;
    final sceneY = (focalScreen.dy - state.scrollY) / state.zoom;
    state = _constrain(state.copyWith(
      zoom: clamped,
      scrollX: focalScreen.dx - clamped * sceneX,
      scrollY: focalScreen.dy - clamped * sceneY,
    ));
  }

  /// Resets to a neutral view: identity in infinite mode, page centred at 100%
  /// (clamped into range) in page mode.
  void reset() {
    final z = 1.0.clamp(_minZoom, _maxZoom);
    state = _constrain(const ViewportState().copyWith(zoom: z));
  }

  /// In page mode, keeps the page within the viewport: centred on any axis
  /// where the scaled page is smaller than the viewport, otherwise clamped so
  /// its edges cannot be dragged inside the viewport edges. No-op when infinite.
  ViewportState _constrain(ViewportState s) {
    if (!_pageMode || _pageSize.isEmpty || _viewportSize.isEmpty) return s;

    final pageW = _pageSize.width * s.zoom;
    final pageH = _pageSize.height * s.zoom;

    final double sx = pageW <= _viewportSize.width
        ? (_viewportSize.width - pageW) / 2
        : s.scrollX.clamp(_viewportSize.width - pageW, 0.0);
    final double sy = pageH <= _viewportSize.height
        ? (_viewportSize.height - pageH) / 2
        : s.scrollY.clamp(_viewportSize.height - pageH, 0.0);

    return s.copyWith(scrollX: sx, scrollY: sy);
  }
}

final viewportProvider =
    StateNotifierProvider.autoDispose<ViewportController, ViewportState>(
  (ref) => ViewportController(),
);
