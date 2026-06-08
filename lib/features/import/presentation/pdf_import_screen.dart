import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../pdf_service.dart';
import '../../editor/presentation/imported_content_notifier.dart';
import '../../editor/presentation/page_notifier.dart';
import '../../../core/constants/app_colors.dart';

class PdfImportScreen extends ConsumerStatefulWidget {
  final int notebookId;
  final int initialPageIndex;

  const PdfImportScreen({super.key, required this.notebookId, required this.initialPageIndex});

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Selecting file...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startImportProcess();
    });
  }

  Future<void> _startImportProcess() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        if (mounted) context.pop();
        return;
      }

      final filePath = result.files.single.path!;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Rendering PDF pages...';
      });

      final pdfService = PDFService();
      final importedPages = await pdfService.renderAll(filePath, widget.notebookId.toString());

      setState(() {
        _statusMessage = 'Creating pages...';
      });

      final pageRepo = ref.read(pageRepositoryProvider);
      final importRepo = ref.read(importRepositoryProvider);

      for (int i = 0; i < importedPages.length; i++) {
        setState(() {
          _progress = (i + 1) / importedPages.length;
        });

        // If it's the very first page and the notebook was just empty/blank,
        // we could inject it into the current page. But the easiest way is 
        // to always append new pages for each PDF page.
        final newPage = await pageRepo.createPage(widget.notebookId);
        
        await importRepo.saveContentsForPage(
          widget.notebookId, 
          newPage.pageIndex, 
          [importedPages[i]],
        );
      }

      // Refresh the notebook pages state so the UI sees the new pages
      await ref.read(pageProvider(widget.notebookId).notifier).initialize();

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Import PDF'),
        backgroundColor: AppColors.surface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 24),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: AppColors.accentRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
