import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/constants/storage_paths.dart';
import '../editor/domain/models/imported_content.dart';

class ImportException implements Exception {
  final String message;
  const ImportException(this.message);
  @override
  String toString() => 'ImportException: $message';
}

class _PdfRenderPayload {
  final RootIsolateToken token;
  final String filePath;
  final String notebookId;
  final String docsDir;

  _PdfRenderPayload(this.token, this.filePath, this.notebookId, this.docsDir);
}

class PDFService {
  PDFService();

  /// Renders all pages of a PDF and creates an ImportedContent for each page.
  /// Runs inside a background isolate to prevent UI thread blocking.
  Future<List<ImportedContent>> renderAll(String filePath, String notebookId) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('PDF not found at path: $filePath');
    }

    final docsDir = (await getApplicationDocumentsDirectory()).path;
    final token = RootIsolateToken.instance!;
    
    final payload = _PdfRenderPayload(token, filePath, notebookId, docsDir);
    
    // Spawn background isolate
    return await compute(_renderPdfIsolate, payload);
  }
}

Future<List<ImportedContent>> _renderPdfIsolate(_PdfRenderPayload payload) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(payload.token);

  PdfDocument? document;
  try {
    document = await PdfDocument.openFile(payload.filePath);
  } catch (e) {
    throw const ImportException('File is not a valid PDF');
  }

  final List<ImportedContent> importedPages = [];
  final pdfHash = payload.filePath.hashCode.toRadixString(16).padLeft(8, '0');

  try {
    final pageCount = document.pagesCount;

    for (int i = 1; i <= pageCount; i++) {
      final relativeCachePath = StoragePaths.getPdfPageCacheRelativePath(payload.notebookId, pdfHash, i);
      final absoluteCachePath = '${payload.docsDir}/$relativeCachePath';

      final diskFile = File(absoluteCachePath);
      if (!await diskFile.exists()) {
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
            await diskFile.parent.create(recursive: true);
            await diskFile.writeAsBytes(bytes);
          }
        } catch (e) {
          debugPrint('Rendering failed for page $i: $e');
        }
      }

      final content = ImportedContent.pdfBackground(
        id: '${DateTime.now().microsecondsSinceEpoch}_$i',
        relativeImagePath: relativeCachePath,
        sourceDescription: '${payload.filePath.split('/').last} — Page $i',
      );
      importedPages.add(content);
    }
  } finally {
    await document.close();
  }

  return importedPages;
}
