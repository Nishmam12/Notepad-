// Interactive layer for committed text boxes: tap to select, drag to move,
// double-tap to edit, and a delete button to remove. The text pixels themselves
// are painted by the combined content layer; this overlay only provides the
// hit-targets and selection chrome, and is only interactive while the lasso
// (selection) tool is active so that pen/eraser/shape input passes through.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/shape_type.dart';
import '../../domain/services/shape_geometry.dart';
import '../canvas_notifier.dart';
import '../viewport_notifier.dart';
import '../shape_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../domain/undo_redo/shape_transform_command.dart';
import '../../domain/undo_redo/lasso_delete_command.dart';

class TextElementOverlay extends ConsumerStatefulWidget {
  final int pageIndex;
  final bool enabled;
  final void Function(ShapeElement shape) onEdit;
  final VoidCallback onChanged;

  const TextElementOverlay({
    super.key,
    required this.pageIndex,
    required this.enabled,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  ConsumerState<TextElementOverlay> createState() => _TextElementOverlayState();
}

class _TextElementOverlayState extends ConsumerState<TextElementOverlay> {
  String? _selectedId;
  ShapeElement? _dragBefore;

  ShapeElement _cloneWithGeometry(ShapeElement s, List<double> geom) {
    return ShapeElement()
      ..id = s.id
      ..type = s.type
      ..color = s.color
      ..strokeWidth = s.strokeWidth
      ..hasFill = s.hasFill
      ..fillColor = s.fillColor
      ..opacity = s.opacity
      ..rotation = s.rotation
      ..text = s.text
      ..fontSize = s.fontSize
      ..fontFamily = s.fontFamily
      ..isBold = s.isBold
      ..isItalic = s.isItalic
      ..svgRelativePath = s.svgRelativePath
      ..zOrder = s.zOrder
      ..geometryData = geom;
  }

  void _move(String id, Offset screenDelta, double zoom) {
    final shapes = ref.read(shapeProvider(widget.pageIndex)).shapes;
    final idx = shapes.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final cur = shapes[idx];
    final r = ShapeGeometry.rectFromGeometry(cur.geometryData)
        .shift(Offset(screenDelta.dx / zoom, screenDelta.dy / zoom));
    ref.read(shapeProvider(widget.pageIndex).notifier).updateShape(
          _cloneWithGeometry(cur, [r.left, r.top, r.right, r.bottom]),
        );
  }

  void _commitMove(String id) {
    final before = _dragBefore;
    _dragBefore = null;
    if (before == null) return;
    final shapes = ref.read(shapeProvider(widget.pageIndex)).shapes;
    final idx = shapes.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final after = shapes[idx];
    if (_listEquals(before.geometryData, after.geometryData)) return;

    ref.read(undoRedoProvider(widget.pageIndex).notifier).push(
          ShapeTransformCommand(
            shapeNotifier: ref.read(shapeProvider(widget.pageIndex).notifier),
            before: before,
            after: after,
          ),
        );
    widget.onChanged();
  }

  void _delete(ShapeElement shape) {
    final command = LassoDeleteCommand(
      canvasNotifier: ref.read(canvasStateProvider(widget.pageIndex).notifier),
      shapeNotifier: ref.read(shapeProvider(widget.pageIndex).notifier),
      deletedStrokes: const [],
      deletedShapes: [shape],
    );
    ref.read(undoRedoProvider(widget.pageIndex).notifier).push(command);
    command.execute();
    setState(() => _selectedId = null);
    widget.onChanged();
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textShapes = ref
        .watch(shapeProvider(widget.pageIndex))
        .shapes
        .where((s) => s.type == ShapeType.textBox)
        .toList();

    if (textShapes.isEmpty) return const SizedBox.shrink();

    final viewport = ref.watch(viewportProvider);
    final zoom = viewport.zoom;

    Rect toScreen(Rect scene) => Rect.fromLTWH(
          viewport.scrollX + zoom * scene.left,
          viewport.scrollY + zoom * scene.top,
          zoom * scene.width,
          zoom * scene.height,
        );

    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Stack(
        children: [
          for (final shape in textShapes)
            ..._buildForShape(
                shape,
                toScreen(ShapeGeometry.rectFromGeometry(shape.geometryData)),
                zoom),
        ],
      ),
    );
  }

  List<Widget> _buildForShape(
      ShapeElement shape, Rect screenRect, double zoom) {
    final isSelected = widget.enabled && _selectedId == shape.id;
    final box = screenRect.inflate(4);

    return [
      Positioned.fromRect(
        rect: box,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedId = shape.id),
          onDoubleTap: () {
            setState(() => _selectedId = null);
            widget.onEdit(shape);
          },
          onPanStart: (_) {
            setState(() => _selectedId = shape.id);
            _dragBefore = shape;
          },
          onPanUpdate: (d) => _move(shape.id, d.delta, zoom),
          onPanEnd: (_) => _commitMove(shape.id),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.25),
                width: isSelected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      if (isSelected)
        Positioned(
          left: box.right - 14,
          top: box.top - 14,
          child: GestureDetector(
            onTap: () => _delete(shape),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentRed,
                ),
                child: const Icon(Icons.close, size: 15, color: Colors.white),
              ),
            ),
          ),
        ),
    ];
  }
}
