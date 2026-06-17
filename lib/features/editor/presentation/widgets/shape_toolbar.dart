import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shape_type.dart';
import '../canvas_notifier.dart';

class ShapeToolbar extends ConsumerWidget {
  const ShapeToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolProvider);
    final isVisible = toolState.activeTool == ToolType.shape;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      top: isVisible ? 80 : 0, // Slides out from beneath the main toolbar
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isVisible ? 1.0 : 0.0,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    _buildShapeBtn(ref, toolState, ShapeType.line, Icons.horizontal_rule),
                    _buildShapeBtn(ref, toolState, ShapeType.arrow, Icons.arrow_right_alt),
                    _buildShapeBtn(ref, toolState, ShapeType.circle, Icons.circle_outlined),
                    _buildShapeBtn(ref, toolState, ShapeType.rectangle, Icons.crop_square),
                    _buildShapeBtn(ref, toolState, ShapeType.triangle, Icons.change_history),
                    _buildShapeBtn(ref, toolState, ShapeType.polygon, Icons.pentagon_outlined),
                    _buildShapeBtn(ref, toolState, ShapeType.diamond, Icons.diamond_outlined),
                    _buildShapeBtn(ref, toolState, ShapeType.textBox, Icons.title),
                    // SVGs are imported via bottom sheet, but we can have an icon here as well or omit. The prompt says: "8 icons for line, arrow, circle, rectangle, triangle, polygon, textBox, SVG".
                    _buildShapeBtn(ref, toolState, ShapeType.svgImage, Icons.image_outlined),
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: AppColors.border,
                    ),
                    _buildSketchyToggle(ref, toolState),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSketchyToggle(WidgetRef ref, ToolState toolState) {
    final isOn = toolState.sketchyShapes;
    return GestureDetector(
      onTap: () => ref.read(toolProvider.notifier).toggleSketchyShapes(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isOn ? AppColors.accentWash : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOn ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Icon(
          Icons.gesture,
          color: isOn ? AppColors.accent : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildShapeBtn(WidgetRef ref, ToolState toolState, ShapeType type, IconData icon) {
    final isSelected = toolState.selectedShapeType == type;
    return GestureDetector(
      onTap: () {
        ref.read(toolProvider.notifier).setShapeType(type);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentWash : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
          size: 20,
        ),
      ),
    );
  }
}
