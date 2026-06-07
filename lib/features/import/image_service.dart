import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_paths.dart';
import '../editor/domain/models/imported_content.dart';
import '../editor/data/storage/pdf_cache_manager.dart'; // We can use PdfCacheManager for image memory cache
import 'pdf_service.dart'; // For ImportException

class ImageProcessPayload {
  final String sourcePath;
  final String destinationPath;

  ImageProcessPayload(this.sourcePath, this.destinationPath);
}

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final PdfCacheManager _cacheManager;

  ImageService(this._cacheManager);

  Future<ImportedContent?> pickFromGallery(String notebookId) async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return null; // User cancelled
    return _processAndSaveImage(xFile.path, notebookId);
  }

  Future<ImportedContent?> pickFromCamera(String notebookId) async {
    final xFile = await _picker.pickImage(source: ImageSource.camera);
    if (xFile == null) return null; // User cancelled
    return _processAndSaveImage(xFile.path, notebookId);
  }

  Future<ImportedContent?> _processAndSaveImage(String sourcePath, String notebookId) async {
    final contentId = DateTime.now().microsecondsSinceEpoch.toString();
    final relativePath = StoragePaths.getFreeImageCacheRelativePath(notebookId, contentId);
    
    final docsDir = await getApplicationDocumentsDirectory();
    final absoluteDestPath = '${docsDir.path}/$relativePath';

    final payload = ImageProcessPayload(sourcePath, absoluteDestPath);

    final success = await compute(_compressAndSaveIsolate, payload);

    if (!success) {
      throw const ImportException('Selected image could not be decoded');
    }

    try {
      final bytes = await File(absoluteDestPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      // Store in memory cache
      await _cacheManager.put(contentId, image);

      // Create ImportedContent record
      return ImportedContent.freeImage(
        id: contentId,
        relativeImagePath: relativePath,
        sourceDescription: 'Image Import',
        x: 100, // Default position
        y: 100, // Default position
        width: image.width > 500 ? 500 : image.width.toDouble(),
        height: image.width > 500 ? (image.height / image.width) * 500 : image.height.toDouble(),
      );
    } catch (e) {
      throw const ImportException('Failed to save image to local storage');
    }
  }

  // Runs on a background isolate
  static Future<bool> _compressAndSaveIsolate(ImageProcessPayload payload) async {
    try {
      final bytes = await File(payload.sourcePath).readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      
      if (decodedImage == null) return false;

      // Progressive resize if it exceeds 2048x2048
      img.Image processedImage = decodedImage;
      if (processedImage.width > 2048 || processedImage.height > 2048) {
        processedImage = img.copyResize(
          processedImage,
          width: processedImage.width > processedImage.height ? 2048 : null,
          height: processedImage.height >= processedImage.width ? 2048 : null,
        );
      }

      // Encode as JPEG quality 85
      final compressedBytes = img.encodeJpg(processedImage, quality: 85);

      final destFile = File(payload.destinationPath);
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(compressedBytes);

      return true;
    } catch (e) {
      return false;
    }
  }
}
