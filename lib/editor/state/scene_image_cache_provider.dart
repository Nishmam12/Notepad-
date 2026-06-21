// App-wide [SceneImageCache] so decoded bitmaps are shared across pages and the
// exporter (no re-decoding per page, and exports render real images). Owned by
// the provider, which disposes it with the container.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../render/scene_image_cache.dart';
import 'scene_controller.dart';

final sceneImageCacheProvider = Provider<SceneImageCache>((ref) {
  final cache = SceneImageCache(baseDir: ref.watch(appDocsPathProvider));
  ref.onDispose(cache.dispose);
  return cache;
});
