import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Strokes and shapes marked for erasure during the current stroke-eraser drag.
///
/// The eraser works in two phases (mirroring Excalidraw): a drag accumulates
/// hit ids here without mutating the scene — the canvas dims them for feedback —
/// and a single delete command commits them on pointer-up, so the whole gesture
/// is one undo step.
class PendingErase {
  final Set<String> strokeIds;
  final Set<String> shapeIds;

  const PendingErase({this.strokeIds = const {}, this.shapeIds = const {}});

  bool get isEmpty => strokeIds.isEmpty && shapeIds.isEmpty;
}

class PendingEraseNotifier extends StateNotifier<PendingErase> {
  PendingEraseNotifier() : super(const PendingErase());

  void addHits(Set<String> strokeIds, Set<String> shapeIds) {
    if (strokeIds.isEmpty && shapeIds.isEmpty) return;
    state = PendingErase(
      strokeIds: {...state.strokeIds, ...strokeIds},
      shapeIds: {...state.shapeIds, ...shapeIds},
    );
  }

  void clear() {
    if (!state.isEmpty) state = const PendingErase();
  }
}

final pendingEraseProvider =
    StateNotifierProvider.autoDispose<PendingEraseNotifier, PendingErase>(
  (ref) => PendingEraseNotifier(),
);

/// One sample of the animated eraser trail (scene coords + capture time in ms).
class EraserTrailPoint {
  final Offset position;
  final int timeMs;
  const EraserTrailPoint(this.position, this.timeMs);
}

class EraserTrailNotifier extends StateNotifier<List<EraserTrailPoint>> {
  EraserTrailNotifier() : super(const []);

  static const int _maxPoints = 80;

  void addPoint(Offset p) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = [...state, EraserTrailPoint(p, now)];
    state =
        next.length > _maxPoints ? next.sublist(next.length - _maxPoints) : next;
  }

  void clear() {
    if (state.isNotEmpty) state = const [];
  }
}

final eraserTrailProvider = StateNotifierProvider.autoDispose<EraserTrailNotifier,
    List<EraserTrailPoint>>((ref) => EraserTrailNotifier());
