// Bottom sheet template picker with visual preview cards for each template type.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/template_type.dart';
import '../../presentation/canvas_notifier.dart';
import '../canvas/layers/template_painter.dart';

/// Shows a bottom sheet with a 2×3 grid of template preview cards and a color selector.
void showTemplatePicker({
  required BuildContext context, 
  required WidgetRef ref,
  required int notebookId,
  required Color currentColor,
  ValueChanged<Color>? onColorChanged,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _TemplatePickerSheet(
      ref: ref,
      notebookId: notebookId,
      currentColor: currentColor,
      onColorChanged: onColorChanged,
    ),
  );
}

class _TemplatePickerSheet extends StatelessWidget {
  final WidgetRef ref;
  final int notebookId;
  final Color currentColor;
  final ValueChanged<Color>? onColorChanged;

  const _TemplatePickerSheet({
    required this.ref,
    required this.notebookId,
    required this.currentColor,
    this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentTemplate = ref.read(toolProvider).template;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Paper Template',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Template grid — 2 columns, wrapping
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: TemplateType.values.map((type) {
                return _TemplateCard(
                  type: type,
                  isSelected: type == currentTemplate,
                  onTap: () {
                    ref.read(toolProvider.notifier).setTemplate(type);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text(
              'Paper Color',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Color(0xFFFFFFFF), // White
                const Color(0xFFFAF7F0), // Cream
                const Color(0xFF1E1E1E), // Dark
              ].map((color) {
                final isSelected = currentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () {
                    onColorChanged?.call(color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.accent : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final TemplateType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Calculate card width: (screen width - padding*2 - gap) / 3
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48 - 24) / 3; // 24px padding each side, 12px*2 gaps

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            children: [
              // Preview tile
              Container(
                width: cardWidth,
                height: cardWidth * 1.3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isSelected
                        ? AppColors.accent
                        : AppColors.border,
                    width: widget.isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CustomPaint(
                    painter: _TemplatePreviewPainter(type: widget.type),
                    size: Size(cardWidth, cardWidth * 1.3),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Label
              Text(
                widget.type.displayName,
                style: TextStyle(
                  color: widget.isSelected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniature preview painter that renders the template pattern at card scale.
class _TemplatePreviewPainter extends CustomPainter {
  final TemplateType type;

  const _TemplatePreviewPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Render template at preview scale
    TemplatePainter.paint(canvas, size, type, Colors.white);
  }

  @override
  bool shouldRepaint(_TemplatePreviewPainter oldDelegate) =>
      type != oldDelegate.type;
}
