import 'package:isar/isar.dart';

import '../../../../shared/isar/isar_service.dart';
import '../../../home/domain/models/note_page.dart';
import '../../domain/models/imported_content.dart';

class ImportRepository {
  final Isar _db;

  ImportRepository([Isar? isar])
      : _db = isar ?? IsarService.instance;

  /// Loads the list of ImportedContent for a given NotePage index in a Notebook
  Future<List<ImportedContent>> loadContentsForPage(int notebookId, int pageIndex) async {
    return await _db.txn(() async {
      final page = await _db.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      return page?.importedContents.toList() ?? [];
    });
  }

  /// Replaces the entire list of ImportedContent for a given NotePage
  Future<void> saveContentsForPage(int notebookId, int pageIndex, List<ImportedContent> contents) async {
    await _db.writeTxn(() async {
      final page = await _db.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        page.importedContents = contents;
        await _db.notePages.put(page);
      }
    });
  }

  /// Adds a single ImportedContent to a given NotePage
  Future<void> addContent(int notebookId, int pageIndex, ImportedContent content) async {
    await _db.writeTxn(() async {
      final page = await _db.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentList = page.importedContents.toList();
        currentList.add(content);
        page.importedContents = currentList;
        await _db.notePages.put(page);
      }
    });
  }

  /// Removes a single ImportedContent by id from a given NotePage
  Future<void> removeContent(int notebookId, int pageIndex, String contentId) async {
    await _db.writeTxn(() async {
      final page = await _db.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentList = page.importedContents.toList();
        currentList.removeWhere((c) => c.id == contentId);
        page.importedContents = currentList;
        await _db.notePages.put(page);
      }
    });
  }

  /// Updates an existing ImportedContent's transform/opacity properties
  Future<void> updateContentTransform(
    int notebookId, 
    int pageIndex, 
    String contentId, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
  }) async {
    await _db.writeTxn(() async {
      final page = await _db.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentList = page.importedContents.toList();
        final index = currentList.indexWhere((c) => c.id == contentId);
        if (index != -1) {
          final content = currentList[index];
          if (x != null) content.x = x;
          if (y != null) content.y = y;
          if (width != null) content.width = width;
          if (height != null) content.height = height;
          if (rotation != null) content.rotation = rotation;
          if (opacity != null) content.opacity = opacity;
          // No need to re-insert, modifying the object in the list modifies it in the object graph
          // but we assign it back anyway to trigger Isar update detection
          page.importedContents = currentList;
          await _db.notePages.put(page);
        }
      }
    });
  }
}
