// Instantiating a library item onto a page: fresh ids (so it never collides
// with existing elements), groups preserved-but-remapped, repositioned so the
// item's top-left lands at the drop point, and re-stacked on top.

import 'dart:ui';

import '../geometry/selection_bounds.dart';
import '../model/library_item.dart';
import '../model/scene_element.dart';
import 'selection_editing.dart';
import 'z_order_service.dart';

class LibraryService {
  LibraryService._();

  /// Returns new elements for inserting [item] with its top-left at [at].
  /// [nextId] mints fresh element ids; [baseZOrder] is the first z value (the
  /// cluster is stacked contiguously from there, preserving relative order).
  static List<SceneElement> instantiate(
    LibraryItem item, {
    required Offset at,
    required String Function() nextId,
    required int baseZOrder,
  }) {
    if (item.elements.isEmpty) return const [];
    final box = SelectionBounds.union(item.elements) ?? Rect.zero;
    final copies = SelectionEditing.duplicate(
      item.elements,
      offset: at - box.topLeft,
      nextId: nextId,
    );
    final ordered = [...copies]..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    return [
      for (int i = 0; i < ordered.length; i++)
        ZOrderService.withZOrder(ordered[i], baseZOrder + i),
    ];
  }
}
