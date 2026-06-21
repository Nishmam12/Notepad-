// A reusable cluster of scene elements saved to the element library. Captured
// from a selection, browsed in the library panel, and dropped back onto any
// page. Pure domain model — JSON persistence lives in the repository.

import 'scene_element.dart';

class LibraryItem {
  final String id;
  final String name;
  final DateTime createdAt;

  /// The captured elements, in their original scene coordinates. Insertion
  /// re-positions and re-ids them (see `LibraryService.instantiate`).
  final List<SceneElement> elements;

  const LibraryItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.elements,
  });

  LibraryItem copyWith({String? name}) => LibraryItem(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        elements: elements,
      );
}
