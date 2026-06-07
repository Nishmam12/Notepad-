// Shares exported files via the system share sheet or saves to device storage.

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportShareService {
  /// Shares a file via the system share sheet.
  static Future<void> shareFile({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType)],
        subject: filename,
      ),
    );
  }

  /// Shares PNG image bytes via the system share sheet.
  static Future<void> sharePng(Uint8List pngBytes, String notebookTitle) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await shareFile(
      bytes: pngBytes,
      filename: '${notebookTitle}_$timestamp.png',
      mimeType: 'image/png',
    );
  }

  /// Shares PDF bytes via the system share sheet.
  static Future<void> sharePdf(Uint8List pdfBytes, String notebookTitle) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await shareFile(
      bytes: pdfBytes,
      filename: '${notebookTitle}_$timestamp.pdf',
      mimeType: 'application/pdf',
    );
  }

  /// Saves PNG bytes to the app's documents directory.
  static Future<String> saveToDocuments(
    Uint8List pngBytes,
    String notebookTitle,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${appDir.path}/exports');
    await exportDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${notebookTitle}_$timestamp.png';
    final file = File('${exportDir.path}/$filename');
    await file.writeAsBytes(pngBytes);

    return file.path;
  }
}
