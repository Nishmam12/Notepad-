// Export popup menu for the editor AppBar — PNG, PDF, and Share options.

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../export/canvas_export_service.dart';
import '../../../export/export_share_service.dart';
import '../../domain/models/stroke.dart';
import '../../domain/models/template_type.dart';

enum _ExportAction { png, pdf, share }

class ExportMenu extends StatelessWidget {
  final List<Stroke> strokes;
  final TemplateType templateType;
  final Color backgroundColor;
  final String notebookTitle;

  const ExportMenu({
    super.key,
    required this.strokes,
    required this.templateType,
    this.backgroundColor = Colors.white,
    this.notebookTitle = 'InkFlow Note',
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ExportAction>(
      icon: const Icon(Icons.more_vert),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (action) => _handleExport(context, action),
      itemBuilder: (context) => [
        _buildMenuItem(
          value: _ExportAction.png,
          icon: Icons.image_outlined,
          label: 'Export as PNG',
        ),
        _buildMenuItem(
          value: _ExportAction.pdf,
          icon: Icons.picture_as_pdf_outlined,
          label: 'Export as PDF',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: _ExportAction.share,
          icon: Icons.share_outlined,
          label: 'Share',
        ),
      ],
    );
  }

  PopupMenuItem<_ExportAction> _buildMenuItem({
    required _ExportAction value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<_ExportAction>(
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    _ExportAction action,
  ) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            SizedBox(width: 12),
            Text('Exporting...'),
          ],
        ),
        duration: Duration(seconds: 30),
        backgroundColor: AppColors.surface,
      ),
    );

    try {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      switch (action) {
        case _ExportAction.png:
          final pngBytes = await CanvasExportService.exportToPng(
            strokes: strokes,
            templateType: templateType,
            backgroundColor: backgroundColor,
          );
          await ExportShareService.sharePng(pngBytes, notebookTitle);
        case _ExportAction.pdf:
          final pdfBytes = await CanvasExportService.exportToPdf(
            strokes: strokes,
            templateType: templateType,
            backgroundColor: backgroundColor,
          );
          await ExportShareService.sharePdf(pdfBytes, notebookTitle);
        case _ExportAction.share:
          final pngBytes = await CanvasExportService.exportToPng(
            strokes: strokes,
            templateType: templateType,
            backgroundColor: backgroundColor,
          );
          await ExportShareService.sharePng(pngBytes, notebookTitle);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export complete'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }
}
