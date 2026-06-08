
import 'dart:ui' as ui;

import '../../domain/models/stroke.dart';
import 'ink_file_storage.dart';
import 'page_thumbnail_service.dart';

import 'package:flutter/foundation.dart';

class PageData {
  final int pageIndex;
  final List<Stroke> strokes;
  final ui.Image? backgroundThumbnail;

  PageData(this.pageIndex, this.strokes, this.backgroundThumbnail);
}

class PageCacheManager {
  // Max capacity 3. Stores current, current-1, current+1.
  @visibleForTesting
  final Map<int, PageData> cache = {};

  /// Fetches from cache. If miss, loads from InkFileStorage and thumbnail service.
  Future<PageData> getPage(int notebookId, int pageIndex) async {
    if (cache.containsKey(pageIndex)) {
      return cache[pageIndex]!;
    }

    final strokes = await InkFileStorage.loadStrokes(
      notebookId: notebookId,
      pageId: pageIndex, // We refactored InkFileStorage to use pageIndex under the hood
    );

    final thumbnail = await PageThumbnailService.getThumbnailLazy(notebookId, pageIndex);

    final data = PageData(pageIndex, strokes, thumbnail);
    cache[pageIndex] = data;

    evictStale(pageIndex);
    return data;
  }

  /// Spawns a background preload of adjacent pages.
  /// (Using a microtask/async to avoid blocking, since isolate for disk IO is sometimes overkill
  /// when dart:io is already async, but we will initiate the load asynchronously.)
  void preloadAdjacent(int notebookId, int currentIndex) {
    // We just trigger getPage for adjacent indices but don't await them.
    // They will populate the cache implicitly.
    if (currentIndex > 0) {
      _preload(notebookId, currentIndex - 1);
    }
    _preload(notebookId, currentIndex + 1);
  }

  Future<void> _preload(int notebookId, int index) async {
    if (!cache.containsKey(index)) {
      await getPage(notebookId, index);
    }
  }

  /// Evicts pages outside [currentIndex - 1, currentIndex + 1]
  @visibleForTesting
  void evictStale(int currentIndex) {
    final keysToRemove = <int>[];
    for (final key in cache.keys) {
      if ((key - currentIndex).abs() > 1) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      final data = cache.remove(key);
      data?.backgroundThumbnail?.dispose();
    }
  }

  /// Clear the entire cache
  void clear() {
    for (final data in cache.values) {
      data.backgroundThumbnail?.dispose();
    }
    cache.clear();
  }
}
