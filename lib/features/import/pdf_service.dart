import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/constants/storage_paths.dart';
import '../editor/domain/models/imported_content.dart';
import '../editor/data/storage/pdf_cache_manager.dart';

class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => 'ImportException: $message';
}

class PDFService {
  final PdfCacheManager _cacheManager;

  PDFService(this._cacheManager);

  /// Renders all pages of a PDF and creates an ImportedContent for each page.
  /// Returns a list of ImportedContent objects representing the PDF pages.
  Future<List<ImportedContent>> renderAll(String filePath, String notebookId) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('PDF not found at path: $filePath');
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
    } catch (e) {
      throw const ImportException('File is not a valid PDF');
    }

    final List<ImportedContent> importedPages = [];
    final docsDir = (await getApplicationDocumentsDirectory()).path;
    // We use a pseudo-random hash based on filename and size as a simple pdf hash
    // The instructions say: use path.hashCode.toRadixString(16).padLeft(8, '0')
    final pdfHash = filePath.hashCode.toRadixString(16).padLeft(8, '0');

    try {
      final pageCount = document.pagesCount;

      for (int i = 1; i <= pageCount; i++) {
        final cacheKey = '${pdfHash}_$i';
        
        // Check memory cache first
        ui.Image? image = await _cacheManager.get(cacheKey);

        final relativeCachePath = StoragePaths.getPdfPageCacheRelativePath(notebookId, pdfHash, i);
        final absoluteCachePath = '$docsDir/$relativeCachePath';

        if (image == null) {
          // Check disk cache
          final diskFile = File(absoluteCachePath);
          if (await diskFile.exists()) {
            try {
              final bytes = await diskFile.readAsBytes();
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              image = frame.image;
              await _cacheManager.put(cacheKey, image);
            } catch (e) {
              debugPrint('Failed to load disk cache for PDF page $i: $e');
            }
          }
        }

        if (image == null) {
          // Render the page
          try {
            final page = await document.getPage(i);
            // Render at 2x device pixel ratio for clarity
            final pageImage = await page.render(
              width: page.width * 2.0,
              height: page.height * 2.0,
              format: PdfPageImageFormat.png,
            );
            await page.close();

            if (pageImage != null) {
              final bytes = pageImage.bytes;

              // Save to disk cache
              try {
                final diskFile = File(absoluteCachePath);
                await diskFile.parent.create(recursive: true);
                await diskFile.writeAsBytes(bytes);
              } catch (e) {
                // Disk write fails -> log error, keep in-memory image
                debugPrint('Failed to save PDF page $i to disk cache: $e');
              }

              // Load into memory cache
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              image = frame.image;
              await _cacheManager.put(cacheKey, image);
            }
          } catch (e) {
            debugPrint('Rendering failed for page $i: $e');
            // Do not abort, just skip rendering this page if it fails.
          }
        }

        // Even if image is null (failed to render), we still create the ImportedContent record.
        // The layer will just skip drawing it until it successfully renders.
        final content = ImportedContent.pdfBackground(
          id: DateTime.now().microsecondsSinceEpoch.toString() + '_$i',
          relativeImagePath: relativeCachePath,
          sourceDescription: '${filePath.split('/').last} — Page $i',
        );
        importedPages.add(content);

        // Yield to the event loop so the UI doesn't completely freeze during massive PDF imports
        await Future.delayed(Duration.zero);
      }
    } finally {
      await document.close();
    }

    return importedPages;
  }
}
