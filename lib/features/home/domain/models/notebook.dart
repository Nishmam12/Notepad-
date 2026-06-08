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
}
