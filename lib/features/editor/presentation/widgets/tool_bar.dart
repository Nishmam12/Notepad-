// Compact vertical floating toolbar pinned to the left edge, vertically centred.
// Pen / eraser tools open a size slider popout beside the bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../canvas_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../../import/presentation/import_bottom_sheet.dart';

class ToolBar extends ConsumerStatefulWidget {
  final int notebookId;
  final int pageIndex;

  const ToolBar({
    super.key,
    required this.notebookId,
    required this.pageIndex,
  });

  @override
  ConsumerState<ToolBar> createState() => _ToolBarState();
}

class _ToolBarState extends ConsumerState<ToolBar> {
  /// Whether the size-slider popout is shown (used by pen/eraser tools).
  bool _sizePanelOpen = false;

  void _onPenTap() {
    final wasPen = ref.read(toolProvider).activeTool == ToolType.pen;
    ref.read(toolProvider.notifier).setPen();
    setState(() => _sizePanelOpen = wasPen ? !_sizePanelOpen : true);
  }

  void _onEraserTap() {
    final tool = ref.read(toolProvider.notifier);
    if (ref.read(toolProvider).activeTool == ToolType.eraser) {
      tool.toggleEraserType();
    } else {
      tool.setEraser();
    }
    setState(() => _sizePanelOpen = true);
  }

  void _selectTool(VoidCallback select) {
    select();
    setState(() => _sizePanelOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final toolState = ref.watch(toolProvider);
    final undoRedoState = ref.watch(undoRedoProvider(widget.pageIndex));

    final showSizePanel = _sizePanelOpen &&
        (toolState.activeTool == ToolType.pen ||
            toolState.activeTool == ToolType.eraser);

    return Positioned.fill(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.shadowFloat,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pen tool — opens the size slider popout.
                      _ToolButton(
                        icon: Icons.edit,
                        isActive: toolState.activeTool == ToolType.pen,
                        activeColor: AppColors.accent,
                        onTap: _onPenTap,
                        tooltip: 'Pen',
                      ),
                      const SizedBox(height: 3),

                      // Eraser tool (tap again to switch pixel/stroke).
                      _ToolButton(
                        icon: toolState.eraserType == EraserType.pixel
                            ? Icons.layers_clear
                            : Icons.auto_fix_high,
                        isActive: toolState.activeTool == ToolType.eraser,
                        activeColor: AppColors.accentYellow,
                        onTap: _onEraserTap,
                        tooltip: toolState.eraserType == EraserType.pixel
                            ? 'Pixel Eraser'
                            : 'Stroke Eraser',
                      ),
                      const SizedBox(height: 3),

                      // Shape tool
                      _ToolButton(
                        icon: Icons.category_outlined,
                        isActive: toolState.activeTool == ToolType.shape,
                        activeColor: AppColors.accentGreen,
                        onTap: () => _selectTool(
                            ref.read(toolProvider.notifier).setShapeTool),
                        tooltip: 'Shapes',
                      ),
                      const SizedBox(height: 3),

                      // Lasso tool
                      _ToolButton(
                        icon: Icons.gesture,
                        isActive: toolState.activeTool == ToolType.lasso,
                        activeColor: AppColors.accentPurple,
                        onTap: () => _selectTool(
                            ref.read(toolProvider.notifier).setLassoTool),
                        tooltip: 'Lasso Selection',
                      ),
                      const SizedBox(height: 3),

                      // Hand tool (pan/zoom)
                      _ToolButton(
                        icon: Icons.pan_tool_outlined,
                        isActive: toolState.activeTool == ToolType.hand,
                        activeColor: AppColors.accentYellow,
                        onTap: () => _selectTool(
                            ref.read(toolProvider.notifier).setHandTool),
                        tooltip: 'Pan (Hand Tool)',
                      ),

                      const _ToolDivider(),

                      // Undo
                      _ToolButton(
                        icon: Icons.undo,
                        isActive: false,
                        activeColor: AppColors.accent,
                        onTap: undoRedoState.canUndo
                            ? () => ref
                                .read(
                                    undoRedoProvider(widget.pageIndex).notifier)
                                .undo()
                            : null,
                        tooltip: 'Undo',
                      ),
                      const SizedBox(height: 3),

                      // Redo
                      _ToolButton(
                        icon: Icons.redo,
                        isActive: false,
                        activeColor: AppColors.accent,
                        onTap: undoRedoState.canRedo
                            ? () => ref
                                .read(
                                    undoRedoProvider(widget.pageIndex).notifier)
                                .redo()
                            : null,
                        tooltip: 'Redo',
                      ),

                      const _ToolDivider(),

                      // Color picker
                      _ColorDot(
                        color: toolState.color,
                        onTap: () => _showColorPicker(context, ref),
                      ),
                      const SizedBox(height: 3),

                      // Import
                      _ToolButton(
                        icon: Icons.file_upload_outlined,
                        isActive: false,
                        activeColor: AppColors.accentGreen,
                        onTap: () {
                          ImportBottomSheet.show(
                              context, widget.notebookId, widget.pageIndex);
                        },
                        tooltip: 'Import',
                      ),
                    ],
                  ),
                ),
              ),

              // Size slider popout (pen / eraser).
              if (showSizePanel) _SizeSliderPanel(size: toolState.size),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    const colors = AppColors.penPalette;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: isSelected ? AppColors.accent : AppColors.border,
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

/// Horizontal size slider that pops out to the right of the toolbar.
class _SizeSliderPanel extends ConsumerWidget {
  final double size;

  const _SizeSliderPanel({required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.shadowFloat,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.line_weight,
              size: 16, color: AppColors.textSecondary),
          SizedBox(
            width: 130,
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
                value: size,
                min: 1.0,
                max: 20.0,
                onChanged: (value) =>
                    ref.read(toolProvider.notifier).setSize(value),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Text(
              '${size.toInt()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin horizontal divider used between groups in the vertical toolbar.
class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 7),
      color: AppColors.border,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            size: 19,
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
    return Tooltip(
      message: 'Color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
