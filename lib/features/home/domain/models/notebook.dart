// Isar collection representing a notebook with metadata.

import 'package:isar/isar.dart';

part 'notebook.g.dart';

@collection
class Notebook {
  Id id = Isar.autoIncrement;

  late String title;

  late DateTime createdAt;

  late DateTime modifiedAt;

  @Index()
  int pageCount = 1;

  int backgroundColor = 0xFFFFFFFF;

  /// Index into [TemplateType.values] for this notebook's paper/page style.
  /// Defaults to 0 (TemplateType.blank).
  int templateIndex = 0;

  /// Canvas layout mode: 0 = infinite whiteboard (free pan/zoom),
  /// 1 = single page (bounded, zoom limited to 50–300%). Defaults to infinite.
  int layoutMode = 0;
}
