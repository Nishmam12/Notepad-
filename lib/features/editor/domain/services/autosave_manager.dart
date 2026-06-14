import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/stroke.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/imported_content.dart';
import '../../data/repositories/shape_repository.dart';
import '../../../home/data/repositories/page_repository.dart';
import '../../data/storage/ink_file_storage.dart';
import '../../data/storage/page_thumbnail_service.dart';
import 'dart:ui' as ui;

class AutosaveManager {
  Timer? _debounceTimer;
  // Serializes saves: each forceSaveAsync runs after the previous one finishes
  // so a forced save (e.g. on a page switch) is never silently dropped while
  // another save is still in flight — dropping it would lose that page's data.
  Future<void> _saveChain = Future<void>.value();
  String? _notebookDir;

  Future<void> initialize(int notebookId) async {
    final appDir = await getApplicationDocumentsDirectory();
    _notebookDir = '${appDir.path}/notes/$notebookId';
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

  void triggerDebouncedSave({
    required int notebookId,
    required int pageIndex,
    required List<Stroke> strokes,
    required List<ShapeElement> shapes,
    required List<ImportedContent> contents,
    required Map<String, ui.Image> loadedImages,
    required ui.Size screenSize,
    required ShapeRepository shapeRepo,
    required PageRepository pageRepo,
    required VoidCallback onSaveComplete,
  }) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      forceSaveAsync(
        notebookId: notebookId,
        pageIndex: pageIndex,
        strokes: strokes,
        shapes: shapes,
        contents: contents,
        loadedImages: loadedImages,
        screenSize: screenSize,
        shapeRepo: shapeRepo,
        pageRepo: pageRepo,
        onSaveComplete: onSaveComplete,
      );
    });
  }

  Future<void> forceSaveAsync({
    required int notebookId,
    required int pageIndex,
    required List<Stroke> strokes,
    required List<ShapeElement> shapes,
    required List<ImportedContent> contents,
    required Map<String, ui.Image> loadedImages,
    required ui.Size screenSize,
    required ShapeRepository shapeRepo,
    required PageRepository pageRepo,
    required VoidCallback onSaveComplete,
  }) {
    // A forced save supersedes any pending debounced save; cancel it so it can't
    // fire again later against torn-down providers with stale data.
    _debounceTimer?.cancel();

    // Queue this save behind any in-flight save instead of dropping it.
    final next = _saveChain.then((_) async {
      // 1. Save Strokes
      await InkFileStorage.saveStrokes(
        notebookId: notebookId,
        pageId: pageIndex,
        strokes: strokes,
      );

      // 2. Save Shapes
      await shapeRepo.saveShapesForPage(notebookId, pageIndex, shapes);

      // 3. Update Thumbnail
      await PageThumbnailService.generateAndSave(
        notebookId,
        pageIndex,
        strokes,
        contents,
        loadedImages,
        shapes,
        screenSize,
      );

      // 4. Update Modified Time
      await pageRepo.updateModifiedAt(notebookId, pageIndex);

      onSaveComplete();
    });

    // Keep the chain alive even if this save fails, but surface the error to the
    // caller awaiting this particular save.
    _saveChain = next.catchError((_) {});
    return next;
  }

  void forceSaveSync({
    required int notebookId,
    required int pageIndex,
    required List<Stroke> strokes,
    required List<ShapeElement> shapes,
    required ShapeRepository shapeRepo,
    required PageRepository pageRepo,
  }) {
    _debounceTimer?.cancel();
    
    // Attempt synchronous stroke save if notebook directory is initialized
    if (_notebookDir != null) {
      try {
        InkFileStorage.saveStrokesSync(
          notebookDir: _notebookDir!,
          pageId: pageIndex,
          strokes: strokes,
        );
      } catch (e) {
        debugPrint('Sync save failed for strokes: $e');
      }
    }

    // Isar synchronous save for shapes and page modified time
    try {
      shapeRepo.saveShapesForPageSync(notebookId, pageIndex, shapes);
      pageRepo.updateModifiedAtSync(notebookId, pageIndex);
    } catch (e) {
      debugPrint('Sync save failed for Isar: $e');
    }
  }
}
