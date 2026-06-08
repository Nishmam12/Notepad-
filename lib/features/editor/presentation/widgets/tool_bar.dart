// Floating toolbar with pen, eraser, undo/redo, color picker, and size slider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/template_type.dart';
import '../canvas_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import 'template_picker.dart';
import '../../../import/presentation/import_bottom_sheet.dart';

class ToolBar extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageIndex;
  final Color? backgroundColor;
  final ValueChanged<Color>? onBackgroundColorChanged;

  const ToolBar({
    super.key, 
    required this.notebookId, 
    required this.pageIndex,
    this.backgroundColor,
    this.onBackgroundColorChanged,
  });

  @override
  ConsumerState<ToolBar> createState() => _ToolBarState();
}

class _ToolBarState extends ConsumerState<ToolBar> {
  @override
  Widget build(BuildContext context) {
    final toolState = ref.watch(toolProvider);
    final undoRedoState = ref.watch(undoRedoProvider(widget.pageIndex));

    final isTablet = MediaQuery.of(context).size.width > 600;

    return Positioned(
      bottom: isTablet ? null : 24,
      left: 16,
      right: isTablet ? null : 16,
      top: isTablet ? 100 : null,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 8 : 12, 
            vertical: isTablet ? 12 : 8
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: isTablet ? Axis.vertical : Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Flex(
              direction: isTablet ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pen tool
                _ToolButton(
                  icon: Icons.edit,
                  isActive: toolState.activeTool == ToolType.pen,
                  activeColor: AppColors.accent,
                  onTap: () => ref.read(toolProvider.notifier).setPen(),
                  tooltip: 'Pen',
                ),
                const SizedBox(width: 4),

                // Eraser tool
                _ToolButton(
                  icon: toolState.eraserType == EraserType.pixel 
                      ? Icons.layers_clear 
                      : Icons.auto_fix_high,
                  isActive: toolState.activeTool == ToolType.eraser,
                  activeColor: AppColors.accentYellow,
                  onTap: () {
                    if (toolState.activeTool == ToolType.eraser) {
                      ref.read(toolProvider.notifier).toggleEraserType();
                    } else {
                      ref.read(toolProvider.notifier).setEraser();
                    }
                  },
                  tooltip: toolState.eraserType == EraserType.pixel 
                      ? 'Pixel Eraser' 
                      : 'Stroke Eraser',
                ),
                const SizedBox(width: 4),
                
                // Shape tool
                _ToolButton(
                  icon: Icons.category_outlined,
                  isActive: toolState.activeTool == ToolType.shape,
                  activeColor: AppColors.accentGreen,
                  onTap: () => ref.read(toolProvider.notifier).setShapeTool(),
                  tooltip: 'Shapes',
                ),
                const SizedBox(width: 4),
                
                // Lasso tool
                _ToolButton(
                  icon: Icons.gesture,
                  isActive: toolState.activeTool == ToolType.lasso,
                  activeColor: AppColors.accentPurple,
                  onTap: () => ref.read(toolProvider.notifier).setLassoTool(),
                  tooltip: 'Lasso Selection',
                ),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Divider
                isTablet 
                    ? const Divider(height: 24, color: AppColors.border)
                    : const VerticalDivider(width: 24, color: AppColors.border),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Undo
                _ToolButton(
                  icon: Icons.undo,
                  isActive: false,
                  activeColor: AppColors.accent,
                  onTap: undoRedoState.canUndo
                      ? () => ref.read(undoRedoProvider(widget.pageIndex).notifier).undo()
                      : null,
                  tooltip: 'Undo',
                ),
                isTablet ? const SizedBox(height: 4) : const SizedBox(width: 4),

                // Redo
                _ToolButton(
                  icon: Icons.redo,
                  isActive: false,
                  activeColor: AppColors.accent,
                  onTap: undoRedoState.canRedo
                      ? () => ref.read(undoRedoProvider(widget.pageIndex).notifier).redo()
                      : null,
                  tooltip: 'Redo',
                ),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Divider
                isTablet 
                    ? const Divider(height: 24, color: AppColors.border)
                    : const VerticalDivider(width: 24, color: AppColors.border),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Template picker
                _ToolButton(
                  icon: Icons.grid_view,
                  isActive: toolState.template != TemplateType.blank,
                  activeColor: AppColors.accentPurple,
                  onTap: () => showTemplatePicker(
                    context: context, 
                    ref: ref,
                    notebookId: widget.notebookId,
                    currentColor: widget.backgroundColor ?? Colors.white,
                    onColorChanged: widget.onBackgroundColorChanged,
                  ),
                  tooltip: 'Change Background Template',
                ),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Divider
                isTablet 
                    ? const Divider(height: 24, color: AppColors.border)
                    : const VerticalDivider(width: 24, color: AppColors.border),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Color picker
                _ColorDot(
                  color: toolState.color,
                  onTap: () => _showColorPicker(context, ref),
                ),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Divider
                isTablet 
                    ? const Divider(height: 24, color: AppColors.border)
                    : const VerticalDivider(width: 24, color: AppColors.border),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Size slider
                SizedBox(
                  width: isTablet ? 40 : 80,
                  height: isTablet ? 80 : 40,
                  child: RotatedBox(
                    quarterTurns: isTablet ? 3 : 0,
                    child: SliderTheme(
                      data: const SliderThemeData(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.accent,
                        trackHeight: 3,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: toolState.size,
                        min: 1.0,
                        max: 20.0,
                        onChanged: (value) => ref.read(toolProvider.notifier).setSize(value),
                      ),
                    ),
                  ),
                ),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Divider
                isTablet 
                    ? const Divider(height: 24, color: AppColors.border)
                    : const VerticalDivider(width: 24, color: AppColors.border),
                isTablet ? const SizedBox(height: 12) : const SizedBox(width: 12),

                // Import
                _ToolButton(
                  icon: Icons.file_upload_outlined,
                  isActive: false,
                  activeColor: AppColors.accentGreen,
                  onTap: () {
                    ImportBottomSheet.show(context, widget.notebookId, widget.pageIndex);
                  },
                  tooltip: 'Import',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final colors = [
      Colors.black,
      Colors.white,
      const Color(0xFFF85149), // red
      const Color(0xFFE3B341), // yellow
      const Color(0xFF3FB950), // green
      const Color(0xFF58A6FF), // blue
      const Color(0xFFBC8CFF), // purple
      const Color(0xFFFF7B72), // coral
      const Color(0xFF79C0FF), // light blue
      const Color(0xFFFFA657), // orange
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick a color',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
                final isSelected =
                    ref.read(toolProvider).color.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    ref.read(toolProvider.notifier).setColor(color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.border,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  final String tooltip;

  const _ToolButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? activeColor
                : isEnabled
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
      ),
    );
  }
}
