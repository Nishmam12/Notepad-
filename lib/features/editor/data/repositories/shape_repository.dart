import 'package:isar/isar.dart';
import '../../../../shared/isar/isar_service.dart';
import '../../../home/domain/models/note_page.dart';
import '../../domain/models/shape_element.dart';

class ShapeRepository {
  final Isar _isar;

  ShapeRepository([Isar? isar]) : _isar = isar ?? IsarService.instance.isar;

  Future<List<ShapeElement>> getShapesForPage(int notebookId, int pageIndex) async {
    return _isar.txn(() async {
      final page = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      return page?.shapes.toList() ?? [];
    });
  }

  Future<void> saveShapesForPage(int notebookId, int pageIndex, List<ShapeElement> shapes) async {
    await _isar.writeTxn(() async {
      final page = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        page.shapes = shapes;
        await _isar.notePages.put(page);
      }
    });
  }

  Future<void> addShape(int notebookId, int pageIndex, ShapeElement shape) async {
    await _isar.writeTxn(() async {
      final page = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentShapes = page.shapes.toList();
        currentShapes.add(shape);
        page.shapes = currentShapes;
        await _isar.notePages.put(page);
      }
    });
  }

  Future<void> removeShape(int notebookId, int pageIndex, String shapeId) async {
    await _isar.writeTxn(() async {
      final page = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentShapes = page.shapes.toList();
        currentShapes.removeWhere((s) => s.id == shapeId);
        page.shapes = currentShapes;
        await _isar.notePages.put(page);
      }
    });
  }

  Future<void> updateShape(int notebookId, int pageIndex, ShapeElement updated) async {
    await _isar.writeTxn(() async {
      final page = await _isar.notePages
          .filter()
          .notebookIdEqualTo(notebookId)
          .and()
          .pageIndexEqualTo(pageIndex)
          .findFirst();

      if (page != null) {
        final currentShapes = page.shapes.toList();
        final index = currentShapes.indexWhere((s) => s.id == updated.id);
        if (index != -1) {
          currentShapes[index] = updated;
          page.shapes = currentShapes;
          await _isar.notePages.put(page);
        }
      }
    });
  }
}
