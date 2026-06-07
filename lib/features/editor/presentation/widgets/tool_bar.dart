// Floating toolbar with pen, eraser, undo/redo, color picker, and size slider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/template_type.dart';
import '../canvas_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import 'template_picker.dart';

class ToolBar extends ConsumerWidget {
  const ToolBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolState = ref.watch(toolProvider);
    final undoRedoState = ref.watch(undoRedoProvider);

    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pen tool
                _ToolButton(
                  icon: Icons.edit,
                  isActive: !toolState.isEraser,
                  activeColor: AppColors.accent,
                  onTap: () => ref.read(toolProvider.notifier).setPen(),
                  tooltip: 'Pen',
                ),
                const SizedBox(width: 4),

                // Eraser tool
                _ToolButton(
                  icon: Icons.auto_fix_high,
                  isActive: toolState.isEraser,
                  activeColor: AppColors.accentYellow,
                  onTap: () => ref.read(toolProvider.notifier).setEraser(),
                  tooltip: 'Eraser',
                ),
                const SizedBox(width: 8),

                // Divider
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),

                // Undo
                _ToolButton(
                  icon: Icons.undo,
                  isActive: false, // Will be wired to history state
                  activeColor: AppColors.textSecondary,
                  onTap: undoRedoState.canUndo
                      ? () => ref.read(undoRedoProvider.notifier).undo()
                      : null,
                  tooltip: 'Undo',
                ),
                const SizedBox(width: 4),

                // Redo
                _ToolButton(
                  icon: Icons.redo,
                  isActive: false,
                  activeColor: AppColors.textSecondary,
                  onTap: undoRedoState.canRedo
                      ? () => ref.read(undoRedoProvider.notifier).redo()
                      : null,
                  tooltip: 'Redo',
                ),
                const SizedBox(width: 8),

                // Divider
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),

                // Color picker
                _ColorDot(
                  color: toolState.color,
                  onTap: () => _showColorPicker(context, ref),
                ),
                const SizedBox(width: 8),

                // Size slider
                SizedBox(
                  width: 80,
                  child: SliderTheme(
                    data: const SliderThemeData(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.accent,
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: toolState.size,
                      min: 1.0,
                      max: 20.0,
                      onChanged: (value) {
                        ref.read(toolProvider.notifier).setSize(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Divider
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),

                // Template picker
                _ToolButton(
                  icon: Icons.grid_view,
                  isActive: toolState.template != TemplateType.blank,
                  activeColor: AppColors.accentPurple,
                  onTap: () => showTemplatePicker(context, ref),
                  tooltip: 'Template',
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
