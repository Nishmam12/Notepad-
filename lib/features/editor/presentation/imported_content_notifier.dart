import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/imported_content.dart';
import '../data/repositories/import_repository.dart';
import '../data/storage/pdf_cache_manager.dart';

class ImportedContentState {
  final List<ImportedContent> contents;
  final Map<String, ui.Image> loadedImages;
  final bool isLoading;
  final String? errorMessage;

  const ImportedContentState({
    this.contents = const [],
    this.loadedImages = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  ImportedContentState copyWith({
    List<ImportedContent>? contents,
    Map<String, ui.Image>? loadedImages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ImportedContentState(
      contents: contents ?? this.contents,
      loadedImages: loadedImages ?? this.loadedImages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ImportedContentNotifier extends StateNotifier<ImportedContentState> {
  final int pageIndex;
  final ImportRepository _repository;
  final PdfCacheManager _cacheManager;

  ImportedContentNotifier(this.pageIndex, this._repository, this._cacheManager)
      : super(const ImportedContentState());

  Future<void> loadForPage(int notebookId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final records = await _repository.loadContentsForPage(notebookId, pageIndex);
      final Map<String, ui.Image> images = Map.from(state.loadedImages);

      final docsDir = await getApplicationDocumentsDirectory();

      for (final record in records) {
        // Use record.id as cache key for all types, as it is unique
        final cacheKey = record.id;
        
        ui.Image? image = await _cacheManager.get(cacheKey);

        if (image == null) {
          final absolutePath = '${docsDir.path}/${record.relativeImagePath}';
          final file = File(absolutePath);
          
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            image = frame.image;
            await _cacheManager.put(cacheKey, image);
          }
        }

        if (image != null) {
          images[record.id] = image;
        }
      }

      if (!mounted) return;
      state = state.copyWith(
        contents: records,
        loadedImages: images,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load imported content: $e',
      );
    }
  }

  Future<void> addContent(int notebookId, ImportedContent content) async {
    await _repository.addContent(notebookId, pageIndex, content);
    await loadForPage(notebookId);
  }

  Future<void> removeContent(int notebookId, String contentId) async {
    await _repository.removeContent(notebookId, pageIndex, contentId);
    
    final updatedImages = Map<String, ui.Image>.from(state.loadedImages);
    updatedImages.remove(contentId);
    
    final updatedContents = state.contents.where((c) => c.id != contentId).toList();
    
    if (!mounted) return;
    state = state.copyWith(
      contents: updatedContents,
      loadedImages: updatedImages,
    );
  }

  Future<void> updateTransform(
    int notebookId, {
    required String id,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
  }) async {
    await _repository.updateContentTransform(
      notebookId,
      pageIndex,
      id,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
      opacity: opacity,
    );
    
    // Optimistic UI update
    final updatedContents = state.contents.map((c) {
      if (c.id == id) {
        if (x != null) c.x = x;
        if (y != null) c.y = y;
        if (width != null) c.width = width;
        if (height != null) c.height = height;
        if (rotation != null) c.rotation = rotation;
        if (opacity != null) c.opacity = opacity;
      }
      return c;
    }).toList();
    
    if (!mounted) return;
    state = state.copyWith(contents: updatedContents);
  }
}

// Global instances for providers
final importRepositoryProvider = Provider((ref) => ImportRepository());
final pdfCacheManagerProvider = Provider((ref) => PdfCacheManager());

final importedContentProvider = StateNotifierProvider.autoDispose
    .family<ImportedContentNotifier, ImportedContentState, int>(
  (ref, pageIndex) {
    return ImportedContentNotifier(
      pageIndex, 
      ref.watch(importRepositoryProvider),
      ref.watch(pdfCacheManagerProvider),
    );
  },
);
