import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../selection_notifier.dart';
import '../viewport_notifier.dart';
import '../../domain/undo_redo/lasso_transform_command.dart';
import '../../domain/undo_redo/lasso_delete_command.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../canvas_notifier.dart';
import '../shape_notifier.dart';

/// Floating transform handles for a lasso selection.
///
/// This overlay lives *outside* the viewport [Transform], so handles stay a
/// constant screen size. It therefore converts at the boundary: selection
/// bounds (scene space) are mapped to screen space for placement via
/// [ViewportState.toViewportRect], and every pointer position is mapped back to
/// scene space ([ViewportState.toScene]) so move/resize/rotate math — and the
/// committed [LassoTransformCommand] — are all expressed in scene units and so
/// behave correctly at any zoom or pan.
class SelectionOverlay extends ConsumerStatefulWidget {
  final int pageIndex;

  const SelectionOverlay({super.key, required this.pageIndex});

  @override
  ConsumerState<SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends ConsumerState<SelectionOverlay> {
  // Captured at the start of a gesture (all in scene space).
  Offset? _dragStartScene;
  Rect? _baseBounds;
  Offset? _anchorScene; // fixed opposite corner during a resize
  Offset? _draggedCornerScene; // the corner being dragged during a resize
  double _rotateStartAngle = 0.0;

  ViewportState get _vp => ref.read(viewportProvider);

  Offset _globalToScene(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return _vp.toScene(box.globalToLocal(global));
    }
    return _vp.toScene(global);
  }

  @override
  Widget build(BuildContext context) {
    final selectionState = ref.watch(selectionProvider);
    final viewport = ref.watch(viewportProvider);

    if (!selectionState.hasSelection || selectionState.selectionBounds == null) {
      return const SizedBox.shrink();
    }

    // Scene bounds → screen bounds (constant 4px visual margin).
    final bounds =
        viewport.toViewportRect(selectionState.selectionBounds!).inflate(4.0);

    return Positioned.fill(
      child: Stack(
        children: [
          // Whole-bounds drag target → move.
          Positioned.fromRect(
            rect: bounds,
            child: GestureDetector(
              onPanStart: (d) => _beginMove(d),
              onPanUpdate: (d) => _updateMove(d),
              onPanEnd: (_) => _commitTransform(),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Corner handles → uniform resize anchored at the opposite corner.
          _buildHandle(
            center: bounds.topLeft,
            onPanStart: (d) => _beginResize(d, Corner.topLeft),
            onPanUpdate: _updateResize,
            onPanEnd: (_) => _commitTransform(),
          ),
          _buildHandle(
            center: bounds.topRight,
            onPanStart: (d) => _beginResize(d, Corner.topRight),
            onPanUpdate: _updateResize,
            onPanEnd: (_) => _commitTransform(),
          ),
          _buildHandle(
            center: bounds.bottomLeft,
            onPanStart: (d) => _beginResize(d, Corner.bottomLeft),
            onPanUpdate: _updateResize,
            onPanEnd: (_) => _commitTransform(),
          ),
          _buildHandle(
            center: bounds.bottomRight,
            onPanStart: (d) => _beginResize(d, Corner.bottomRight),
            onPanUpdate: _updateResize,
            onPanEnd: (_) => _commitTransform(),
          ),

          // Rotation handle (above top-centre).
          _buildHandle(
            center: Offset(bounds.center.dx, bounds.top - 32),
            visibleSize: 24,
            icon: Icons.rotate_right,
            onPanStart: (d) => _beginRotate(d),
            onPanUpdate: _updateRotate,
            onPanEnd: (_) => _commitTransform(),
          ),

          // Delete button (top-right).
          Positioned(
            left: bounds.right - 24,
            top: bounds.top - 24,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _commitDelete(selectionState);
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentRed,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),

          // Deselect button below bounds.
          Positioned(
            left: bounds.left,
            top: bounds.bottom + 10,
            width: bounds.width,
            child: Center(
              child: GestureDetector(
                onTap: () =>
                    ref.read(selectionProvider.notifier).clearSelection(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.shadowCard,
                  ),
                  child: const Text(
                    'Deselect',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Move -----------------------------------------------------------------

  void _beginMove(DragStartDetails d) {
    _baseBounds = ref.read(selectionProvider).selectionBounds;
    _dragStartScene = _globalToScene(d.globalPosition);
    ref.read(selectionProvider.notifier).beginTransform();
  }

  void _updateMove(DragUpdateDetails d) {
    if (_dragStartScene == null) return;
    final cur = _globalToScene(d.globalPosition);
    ref.read(selectionProvider.notifier).setMove(cur - _dragStartScene!);
  }

  // ---- Resize ---------------------------------------------------------------

  void _beginResize(DragStartDetails d, Corner corner) {
    final base = ref.read(selectionProvider).selectionBounds;
    if (base == null) return;
    _baseBounds = base;
    _dragStartScene = _globalToScene(d.globalPosition);
    _draggedCornerScene = corner.of(base);
    _anchorScene = corner.opposite.of(base);
    ref.read(selectionProvider.notifier).beginTransform();
  }

  void _updateResize(DragUpdateDetails d) {
    if (_dragStartScene == null ||
        _anchorScene == null ||
        _draggedCornerScene == null) {
      return;
    }
    final delta = _globalToScene(d.globalPosition) - _dragStartScene!;
    final newDragged = _draggedCornerScene! + delta;
    final initialDist = (_draggedCornerScene! - _anchorScene!).distance;
    if (initialDist <= 0.0001) return;
    final scale = (newDragged - _anchorScene!).distance / initialDist;
    // Clamp to avoid collapsing/exploding the selection on a stray drag.
    final clamped = scale.clamp(0.05, 20.0);
    ref.read(selectionProvider.notifier).setResize(_anchorScene!, clamped);
  }

  // ---- Rotate ---------------------------------------------------------------

  void _beginRotate(DragStartDetails d) {
    final base = ref.read(selectionProvider).selectionBounds;
    if (base == null) return;
    _baseBounds = base;
    ref.read(selectionProvider.notifier).beginTransform();
    final start = _globalToScene(d.globalPosition);
    _rotateStartAngle = _angleFrom(base.center, start);
  }

  void _updateRotate(DragUpdateDetails d) {
    final base = _baseBounds;
    if (base == null) return;
    final cur = _globalToScene(d.globalPosition);
    final angle = _angleFrom(base.center, cur) - _rotateStartAngle;
    ref.read(selectionProvider.notifier).setRotation(angle);
  }

  double _angleFrom(Offset center, Offset p) =>
      math.atan2(p.dy - center.dy, p.dx - center.dx);

  // ---- Commit ---------------------------------------------------------------

  void _commitTransform() {
    final live = ref.read(selectionProvider);
    final scale = live.currentScale;
    final rotation = live.currentRotation;
    final translation = live.currentTranslation;
    final center = live.rotationCenter ?? _baseBounds?.center;
    final anchor = live.scaleAnchor ?? center;
    final strokeIds = live.selectedStrokeIds;
    final shapeIds = live.selectedShapeIds;

    ref.read(selectionProvider.notifier).endTransform();
    _dragStartScene = null;
    _anchorScene = null;
    _draggedCornerScene = null;

    final hasScale = (scale - 1.0).abs() > 0.001;
    final hasRotation = rotation.abs() > 0.0005;
    final hasMove = translation.distance > 0.1;

    if ((hasScale || hasRotation || hasMove) &&
        center != null &&
        (strokeIds.isNotEmpty || shapeIds.isNotEmpty)) {
      final canvasNotifier =
          ref.read(canvasStateProvider(widget.pageIndex).notifier);
      final shapeNotifier = ref.read(shapeProvider(widget.pageIndex).notifier);

      final command = LassoTransformCommand(
        canvasNotifier: canvasNotifier,
        shapeNotifier: shapeNotifier,
        center: center,
        anchor: anchor,
        scale: scale,
        rotation: rotation,
        translation: translation,
        strokeIds: strokeIds,
        shapeIds: shapeIds,
        strokesSnapshot:
            ref.read(canvasStateProvider(widget.pageIndex)).completedStrokes,
        shapesSnapshot: ref.read(shapeProvider(widget.pageIndex)).shapes,
      );
      ref.read(undoRedoProvider(widget.pageIndex).notifier).push(command);
      command.execute();
    }
    _baseBounds = null;
  }

  void _commitDelete(SelectionState state) {
    final canvasState = ref.read(canvasStateProvider(widget.pageIndex));
    final shapeState = ref.read(shapeProvider(widget.pageIndex));

    final deletedStrokes = canvasState.completedStrokes
        .where((s) => state.selectedStrokeIds.contains(s.id))
        .toList();
    final deletedShapes = shapeState.shapes
        .where((s) => state.selectedShapeIds.contains(s.id))
        .toList();

    final command = LassoDeleteCommand(
      canvasNotifier: ref.read(canvasStateProvider(widget.pageIndex).notifier),
      shapeNotifier: ref.read(shapeProvider(widget.pageIndex).notifier),
      deletedStrokes: deletedStrokes,
      deletedShapes: deletedShapes,
    );

    ref.read(undoRedoProvider(widget.pageIndex).notifier).push(command);
    command.execute();

    ref.read(selectionProvider.notifier).deleteSelection();
  }

  Widget _buildHandle({
    required Offset center,
    double visibleSize = 16,
    IconData? icon,
    required void Function(DragStartDetails) onPanStart,
    required void Function(DragUpdateDetails) onPanUpdate,
    required void Function(DragEndDetails) onPanEnd,
  }) {
    return Positioned(
      left: center.dx - 24, // 48/2
      top: center.dy - 24,
      child: GestureDetector(
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: Container(
          width: 48,
          height: 48,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: visibleSize,
            height: visibleSize,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: icon != null
                ? Icon(icon, size: visibleSize * 0.6, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// A bounds corner, with the diagonally opposite corner used as a resize anchor.
enum Corner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  Corner get opposite => switch (this) {
        Corner.topLeft => Corner.bottomRight,
        Corner.topRight => Corner.bottomLeft,
        Corner.bottomLeft => Corner.topRight,
        Corner.bottomRight => Corner.topLeft,
      };

  Offset of(Rect r) => switch (this) {
        Corner.topLeft => r.topLeft,
        Corner.topRight => r.topRight,
        Corner.bottomLeft => r.bottomLeft,
        Corner.bottomRight => r.bottomRight,
      };
}
