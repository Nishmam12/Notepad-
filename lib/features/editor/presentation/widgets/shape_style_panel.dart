import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/undo_redo/shape_transform_command.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../selection_notifier.dart';
import '../shape_notifier.dart';

/// Floating style controls for a single selected shape — change its colour,
/// stroke width, and fill after it has been drawn. Each edit is one undoable
/// [ShapeTransformCommand] (before → after). Only shown when exactly one shape
/// (and no strokes) is selected.
class ShapeStylePanel extends ConsumerWidget {
  final int pageIndex;
  final VoidCallback onChanged;

  const ShapeStylePanel({
    super.key,
    required this.pageIndex,
    required this.onChanged,
  });

  static const List<double> _widths = [2, 4, 8, 14];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final shapes = ref.watch(shapeProvider(pageIndex)).shapes;

    if (selection.selectedShapeIds.length != 1 ||
        selection.selectedStrokeIds.isNotEmpty ||
        selection.isTransforming) {
      return const SizedBox.shrink();
    }

    final id = selection.selectedShapeIds.first;
    ShapeElement? shape;
    for (final s in shapes) {
      if (s.id == id) {
        shape = s;
        break;
      }
    }
    if (shape == null) return const SizedBox.shrink();
    final current = shape;

    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppColors.shadowFloat,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final color in AppColors.penPalette)
                  _colorDot(ref, current, color),
                _divider(),
                for (final w in _widths) _widthBtn(ref, current, w),
                _divider(),
                _fillBtn(ref, current),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _apply(WidgetRef ref, ShapeElement before, ShapeElement after) {
    final command = ShapeTransformCommand(
      shapeNotifier: ref.read(shapeProvider(pageIndex).notifier),
      before: before,
      after: after,
    );
    ref.read(undoRedoProvider(pageIndex).notifier).push(command);
    command.execute();
    onChanged();
  }

  Widget _colorDot(WidgetRef ref, ShapeElement shape, Color color) {
    final value = color.toARGB32();
    final isSelected = shape.color == value;
    return GestureDetector(
      onTap: () => _apply(
        ref,
        shape,
        shape.copyWith(
          color: value,
          // Keep the fill in step with the stroke colour when filled.
          fillColor: shape.hasFill ? value : null,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  Widget _widthBtn(WidgetRef ref, ShapeElement shape, double width) {
    final isSelected = (shape.strokeWidth - width).abs() < 0.01;
    return GestureDetector(
      onTap: () => _apply(ref, shape, shape.copyWith(strokeWidth: width)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentWash : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Container(
          width: width.clamp(2, 14) + 4,
          height: width.clamp(2, 14) + 4,
          decoration: const BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _fillBtn(WidgetRef ref, ShapeElement shape) {
    return GestureDetector(
      onTap: () => _apply(
        ref,
        shape,
        shape.copyWith(
          hasFill: !shape.hasFill,
          fillColor: shape.color,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: shape.hasFill ? AppColors.accentWash : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: shape.hasFill ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Icon(
          shape.hasFill ? Icons.format_color_fill : Icons.format_color_reset,
          size: 18,
          color: shape.hasFill ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: AppColors.border,
      );
}
