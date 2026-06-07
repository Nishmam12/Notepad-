// Isar collection representing a single page within a notebook.

import 'package:isar/isar.dart';

import '../../../editor/domain/models/imported_content.dart';

part 'note_page.g.dart';

@collection
class NotePage {
  Id id = Isar.autoIncrement;

  @Index()
  late int notebookId;

  late int pageIndex;

  late DateTime createdAt;

  // Phase 4: Imported PDF backgrounds and free images
  List<ImportedContent> importedContents = [];

  late DateTime modifiedAt;
  
  // Cache buster
}
