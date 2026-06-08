import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/shape_type.dart';
import '../canvas_notifier.dart';

class ShapeToolbar extends ConsumerWidget {
  const ShapeToolbar({Key? key}) : super(key: key);

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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                    _buildShapeBtn(ref, toolState, ShapeType.textBox, Icons.title),
                    // SVGs are imported via bottom sheet, but we can have an icon here as well or omit. The prompt says: "8 icons for line, arrow, circle, rectangle, triangle, polygon, textBox, SVG".
                    _buildShapeBtn(ref, toolState, ShapeType.svgImage, Icons.image_outlined),
                  ],
                ),
              ),
            ),
          ),
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
          color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppColors.accent : AppColors.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}
